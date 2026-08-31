-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Chat, Requests, Patient Name & Donation Confirmation Loop
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Add patient_name to blood_requests
alter table public.blood_requests
  add column if not exists patient_name text not null default 'Patient';

-- 2. Update status check constraint to include 'accepted'
alter table public.blood_requests
  drop constraint if exists blood_requests_status_check;

alter table public.blood_requests
  add constraint blood_requests_status_check
  check (status in ('active','accepted','fulfilled','cancelled','expired','closed'));

-- 3. Check if a donor currently has an active accepted response
create or replace function public.donor_has_active_commitment(p_donor_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.blood_requests br
    join public.request_responses rr on rr.request_id = br.id
    where rr.donor_id = p_donor_id
      and br.status = 'accepted'
  );
$$;

revoke all on function public.donor_has_active_commitment(uuid) from public, anon;
grant execute on function public.donor_has_active_commitment(uuid) to authenticated;

-- 4. RPC: Respond to blood request (locks out other requests and sets status = 'accepted')
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

  -- Check cooldown: if last_donation_date within 90 days
  if v_donor_profile.last_donation_date is not null
     and v_donor_profile.last_donation_date + interval '90 days' > now() then
    return jsonb_build_object('success', false, 'message', 'Donor is currently on 90-day cooldown');
  end if;

  -- Check if donor already has an active accepted commitment
  select public.donor_has_active_commitment(v_donor_id) into v_has_commitment;
  if v_has_commitment then
    return jsonb_build_object('success', false, 'message', 'You already have an active blood request in progress');
  end if;

  -- Get request
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

-- 5. RPC: Confirm blood donation (Seeker side: Yes -> fulfilled + cooldown; No -> release donor & reopen request)
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

    -- If donor exists, update donor last_donation_date and increment total_donations
    if v_donor_id is not null then
      update public.profiles
      set last_donation_date = now(),
          total_donations = coalesce(total_donations, 0) + 1,
          updated_at = now()
      where id = v_donor_id;
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
