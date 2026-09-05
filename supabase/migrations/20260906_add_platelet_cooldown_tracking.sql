-- Add platelet donation tracking to donor profiles and make the
-- respond / confirm RPCs type-aware.
--
-- Cooldown rules:
--   Whole blood: 90 days between whole-blood donations.
--   Platelets:    7 days between platelet donations.
--   Whole blood also blocks platelets for 7 days (platelets are
--   collected from whole blood in some protocols).
--   Platelets do NOT extend the whole-blood 90-day clock.
--
-- Column design:
--   last_donation_date        — kept as-is, now semantically means
--                               "last whole-blood donation date".
--   last_platelet_donation_date — new, tracks last platelet donation.
--   can_donate_platelets      — new, donor self-declared eligibility.
--
-- can_donate_whole_blood is NOT added because active_role = 'donor'
-- already implies whole-blood eligibility. Adding a redundant flag
-- would create a second source of truth that can drift.

-- 1. Add platelet columns to profiles ──────────────────────────────────────

alter table public.profiles
  add column if not exists can_donate_platelets boolean not null default false;

alter table public.profiles
  add column if not exists last_platelet_donation_date timestamptz
    check (last_platelet_donation_date is null or last_platelet_donation_date <= now());

comment on column public.profiles.can_donate_platelets is
  'Donor self-declared platelet eligibility (informational, not medically verified)';

comment on column public.profiles.last_platelet_donation_date is
  'Timestamp of last platelet donation — used for 7-day platelet cooldown';

-- 2. Recreate profiles_public view with new columns ────────────────────────
-- can_donate_platelets is non-sensitive (same category as active_role).
-- last_platelet_donation_date follows the same show/hide pattern as
-- last_donation_date (controlled by show_last_donation_date).

drop view if exists public.profiles_public;

create view public.profiles_public as
select
  id,
  name,
  blood_group,
  city,
  latitude,
  longitude,
  active_role,
  donor_classification,
  -- hemoglobin_level excluded (sensitive health data)
  -- health_disclosures excluded (sensitive health data)
  -- phone excluded (PII — only visible to profile owner)
  -- email excluded (PII — only visible to profile owner)
  -- fcm_token excluded (PII — only visible to profile owner)
  is_verified,
  is_top_donor,
  is_suspended,
  is_admin,
  last_donation_date,
  last_platelet_donation_date,
  can_donate_platelets,
  onboarding_complete,
  health_info_complete,
  profile_photo_url,
  bio,
  total_donations,
  show_last_donation_date,
  deleted_at,
  created_at,
  updated_at
from public.profiles;

grant select on public.profiles_public to authenticated;

-- 3. Rewrite respond_to_blood_request with type-aware cooldown ─────────────
-- Key changes:
--   - Reads blood_requests.donation_type from the target request
--   - For platelet requests: checks can_donate_platelets flag, then
--     applies 7-day cooldown from last_platelet_donation_date AND
--     7-day block from last_donation_date (whole blood blocks platelets)
--   - For blood requests: applies 90-day cooldown from last_donation_date
--     (unchanged behaviour)

create or replace function public.respond_to_blood_request(
  p_request_id uuid,
  p_message text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_donor_id uuid := auth.uid();
  v_donor_profile record;
  v_request record;
  v_has_commitment boolean;
begin
  if v_donor_id is null then
    return jsonb_build_object('success', false, 'message', 'Not authenticated');
  end if;

  -- Get donor profile
  select * into v_donor_profile
  from public.profiles
  where id = v_donor_id;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Donor profile not found');
  end if;

  -- Get request (need donation_type for cooldown logic)
  select * into v_request
  from public.blood_requests
  where id = p_request_id;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Request not found');
  end if;

  if v_request.status <> 'active' then
    return jsonb_build_object('success', false, 'message', 'This request is no longer active');
  end if;

  if v_request.requester_id = v_donor_id then
    return jsonb_build_object('success', false, 'message', 'You cannot respond to your own request');
  end if;

  -- Type-aware cooldown check
  if v_request.donation_type = 'platelet' then
    -- Platelet requests require the donor to have opted in
    if not coalesce(v_donor_profile.can_donate_platelets, false) then
      return jsonb_build_object('success', false,
        'message', 'Platelet donation requires platelet donor eligibility');
    end if;
    -- 7-day cooldown from last platelet donation
    if v_donor_profile.last_platelet_donation_date is not null
       and v_donor_profile.last_platelet_donation_date + interval '7 days' > now() then
      return jsonb_build_object('success', false,
        'message', 'Donor is currently on 7-day platelet cooldown');
    end if;
    -- Whole blood donation also blocks platelets for 7 days
    if v_donor_profile.last_donation_date is not null
       and v_donor_profile.last_donation_date + interval '7 days' > now() then
      return jsonb_build_object('success', false,
        'message', 'Donor is currently on cooldown after whole blood donation');
    end if;
  else
    -- Blood requests: 90-day cooldown from last whole-blood donation
    if v_donor_profile.last_donation_date is not null
       and v_donor_profile.last_donation_date + interval '90 days' > now() then
      return jsonb_build_object('success', false,
        'message', 'Donor is currently on 90-day cooldown');
    end if;
  end if;

  -- Check if donor already has an active accepted commitment
  select public.donor_has_active_commitment(v_donor_id) into v_has_commitment;
  if v_has_commitment then
    return jsonb_build_object('success', false, 'message', 'You already have an active blood request in progress');
  end if;

  -- Insert response row (upsert)
  insert into public.request_responses (request_id, donor_id, message, responded_at)
  values (p_request_id, v_donor_id, p_message, now())
  on conflict (request_id, donor_id)
  do update set message = excluded.message, responded_at = now();

  -- Update blood_requests status to 'accepted' and set fulfilled_by_donor_id
  update public.blood_requests
  set status = 'accepted',
      fulfilled_by_donor_id = v_donor_id,
      updated_at = now()
  where id = p_request_id;

  return jsonb_build_object('success', true, 'request_id', p_request_id);
end;
$$;

revoke all on function public.respond_to_blood_request(uuid, text) from public, anon;
grant execute on function public.respond_to_blood_request(uuid, text) to authenticated;

-- 4. Rewrite confirm_blood_donation with type-aware date recording ─────────
-- Key changes:
--   - Reads the request's donation_type
--   - For platelet donations: sets last_platelet_donation_date only
--   - For blood donations: sets last_donation_date only (unchanged)
--   - total_donations increment is identical for both types

create or replace function public.confirm_blood_donation(
  p_request_id uuid,
  p_confirmed boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_request record;
  v_donor_id uuid;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'message', 'Not authenticated');
  end if;

  -- Get request and verify requester is the current user
  select * into v_request
  from public.blood_requests
  where id = p_request_id;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Request not found');
  end if;

  if v_request.requester_id <> v_user_id and not public.is_admin() then
    return jsonb_build_object('success', false, 'message', 'Only the request creator can confirm donation');
  end if;

  v_donor_id := v_request.fulfilled_by_donor_id;

  if p_confirmed then
    -- Mark request fulfilled
    update public.blood_requests
    set status = 'fulfilled',
        fulfilled_at = now(),
        updated_at = now()
    where id = p_request_id;

    -- Type-aware donation date recording
    if v_donor_id is not null then
      if v_request.donation_type = 'platelet' then
        -- Platelet donation: record platelet date only
        update public.profiles
        set last_platelet_donation_date = now(),
            total_donations = coalesce(total_donations, 0) + 1,
            updated_at = now()
        where id = v_donor_id;
      else
        -- Whole blood donation: record whole-blood date only
        update public.profiles
        set last_donation_date = now(),
            total_donations = coalesce(total_donations, 0) + 1,
            updated_at = now()
        where id = v_donor_id;
      end if;
    end if;

    return jsonb_build_object('success', true, 'status', 'fulfilled');
  else
    -- Did not donate / Cancel match: release donor and reopen request
    update public.blood_requests
    set status = 'active',
        fulfilled_by_donor_id = null,
        updated_at = now()
    where id = p_request_id;

    if v_donor_id is not null then
      delete from public.request_responses
      where request_id = p_request_id and donor_id = v_donor_id;
    end if;

    return jsonb_build_object('success', true, 'status', 'active');
  end if;
end;
$$;

revoke all on function public.confirm_blood_donation(uuid, boolean) from public, anon;
grant execute on function public.confirm_blood_donation(uuid, boolean) to authenticated;
