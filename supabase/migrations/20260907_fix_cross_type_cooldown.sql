-- Fix cross-type donation cooldown gap.
--
-- Bug: the whole-blood branch of respond_to_blood_request only checked
-- last_donation_date (same-type 90-day), missing the 7-day wait after
-- a platelet donation. A donor who donated platelets yesterday could
-- immediately respond to a whole-blood request.
--
-- Additionally, get_next_donation_eligible_date returned a single merged
-- date (greatest of both same-type cooldowns) which conflated the two
-- independent eligibility clocks. It now returns per-type dates as JSONB.
--
-- Cooldown rules after this fix:
--   Whole blood eligible when:
--     last_donation_date is null OR >= 90 days ago   (same-type)
--     AND last_platelet_donation_date is null OR >= 7 days ago (cross-type)
--   Platelet eligible when:
--     last_platelet_donation_date is null OR >= 7 days ago (same-type)
--     AND last_donation_date is null OR >= 7 days ago      (cross-type)
--
-- Next eligible dates:
--   next_whole_blood_date = max(last_donation_date + 90d,
--                               last_platelet_donation_date + 7d)
--   next_platelet_date    = max(last_platelet_donation_date + 7d,
--                               last_donation_date + 7d)
--   A null date means "no constraint from that direction", not blocking.

-- 1. Fix respond_to_blood_request: add missing PLT->WB cross-check ─────────

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

  -- Type-aware cooldown check (same-type + cross-type)
  if v_request.donation_type = 'platelet' then
    -- Platelet requests require the donor to have opted in
    if not coalesce(v_donor_profile.can_donate_platelets, false) then
      return jsonb_build_object('success', false,
        'message', 'Platelet donation requires platelet donor eligibility');
    end if;
    -- Same-type: 7-day cooldown from last platelet donation
    if v_donor_profile.last_platelet_donation_date is not null
       and v_donor_profile.last_platelet_donation_date + interval '7 days' > now() then
      return jsonb_build_object('success', false,
        'message', 'Donor is currently on 7-day platelet cooldown');
    end if;
    -- Cross-type: whole blood donation blocks platelets for 7 days
    if v_donor_profile.last_donation_date is not null
       and v_donor_profile.last_donation_date + interval '7 days' > now() then
      return jsonb_build_object('success', false,
        'message', 'Donor is currently on cooldown after whole blood donation');
    end if;
  else
    -- Same-type: 90-day cooldown from last whole-blood donation
    if v_donor_profile.last_donation_date is not null
       and v_donor_profile.last_donation_date + interval '90 days' > now() then
      return jsonb_build_object('success', false,
        'message', 'Donor is currently on 90-day cooldown');
    end if;
    -- Cross-type: platelet donation blocks whole blood for 7 days
    if v_donor_profile.last_platelet_donation_date is not null
       and v_donor_profile.last_platelet_donation_date + interval '7 days' > now() then
      return jsonb_build_object('success', false,
        'message', 'Donor is currently on cooldown after platelet donation');
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

-- 2. Rewrite get_next_donation_eligible_date to return per-type dates ──────
-- Return type changes from DATE to JSONB.
-- Shape: { "next_whole_blood_date": "YYYY-MM-DD" | null,
--          "next_platelet_date":    "YYYY-MM-DD" | null }
--
-- Whole blood next date = max(last_donation_date + 90d,
--                             last_platelet_donation_date + 7d)
-- Platelet next date   = max(last_platelet_donation_date + 7d,
--                             last_donation_date + 7d)
-- Null input = no constraint from that direction (not a blocking date).

drop function if exists public.get_next_donation_eligible_date(uuid);

create function public.get_next_donation_eligible_date(p_donor_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_last_blood timestamptz;
  v_last_platelet timestamptz;
  v_wb_from_same date;
  v_wb_from_cross date;
  v_plt_from_same date;
  v_plt_from_cross date;
  v_next_wb date;
  v_next_plt date;
begin
  select last_donation_date, last_platelet_donation_date
  into v_last_blood, v_last_platelet
  from public.profiles
  where id = p_donor_id;

  -- Never donated either type: both dates are null (immediately eligible)
  if v_last_blood is null and v_last_platelet is null then
    return jsonb_build_object(
      'next_whole_blood_date', null,
      'next_platelet_date', null
    );
  end if;

  -- Whole blood: same-type constraint (90 days from last whole blood)
  v_wb_from_same := case
    when v_last_blood is not null then (v_last_blood + interval '90 days')::date
    else null
  end;

  -- Whole blood: cross-type constraint (7 days from last platelet)
  v_wb_from_cross := case
    when v_last_platelet is not null then (v_last_platelet + interval '7 days')::date
    else null
  end;

  -- Platelet: same-type constraint (7 days from last platelet)
  v_plt_from_same := case
    when v_last_platelet is not null then (v_last_platelet + interval '7 days')::date
    else null
  end;

  -- Platelet: cross-type constraint (7 days from last whole blood)
  v_plt_from_cross := case
    when v_last_blood is not null then (v_last_blood + interval '7 days')::date
    else null
  end;

  -- Per-type next eligible = the later (max) of its two constraints.
  -- Null means "no constraint", so coalesce to epoch for comparison,
  -- then convert back: if the result is epoch, return null.
  v_next_wb := greatest(
    coalesce(v_wb_from_same, '1970-01-01'::date),
    coalesce(v_wb_from_cross, '1970-01-01'::date)
  );

  v_next_plt := greatest(
    coalesce(v_plt_from_same, '1970-01-01'::date),
    coalesce(v_plt_from_cross, '1970-01-01'::date)
  );

  return jsonb_build_object(
    'next_whole_blood_date',
    case when v_next_wb > '1970-01-01'::date then v_next_wb else null end,
    'next_platelet_date',
    case when v_next_plt > '1970-01-01'::date then v_next_plt else null end
  );
end;
$$;

revoke all on function public.get_next_donation_eligible_date(uuid) from public, anon;
grant execute on function public.get_next_donation_eligible_date(uuid) to authenticated;
