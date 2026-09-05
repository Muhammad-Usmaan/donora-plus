-- 20260906_feedback_redesign.sql
-- Redesigns donation feedback from a simple "appreciation" count to:
--   1. Star rating (1-5) from the seeker
--   2. Boolean is_appreciated ("Is donor appreciated?")
--   3. Appreciation fraction = appreciated_count / total_donations
--
-- Key design decisions:
-- - total_donations (existing stored column, incremented by confirm_blood_donation)
--   is the denominator, NOT total feedback submitted.  Feedback is optional, so
--   a donor with 10 donations but only 3 feedbacks (all positive) shows 3/10, not 3/3.
-- - Each completed donation (request) receives at most one feedback row.
-- - The old give_appreciation / get_donor_appreciation_stats RPCs are replaced.

-- ── 1. Restructure appreciations table ──────────────────────────────────────

-- Link each feedback row to the specific fulfilled request it rates.
alter table public.appreciations
  add column request_id uuid;

-- Star rating: 1-5, required.
alter table public.appreciations
  add column star_rating integer;

-- Binary appreciation signal: seeker answers "Is donor appreciated?"
alter table public.appreciations
  add column is_appreciated boolean;

-- Backfill existing rows (from the old simple-appreciation design)
-- with neutral defaults so NOT NULL constraints can be applied safely.
update public.appreciations
  set star_rating = 3, is_appreciated = true
  where star_rating is null;

update public.appreciations
  set request_id = id  -- use the appreciation's own uuid as a placeholder
  where request_id is null;

-- Now enforce NOT NULL.
alter table public.appreciations
  alter column star_rating set not null;

alter table public.appreciations
  alter column is_appreciated set not null;

alter table public.appreciations
  alter column request_id set not null;

-- Constraints.
alter table public.appreciations
  add constraint appreciations_star_rating_check
  check (star_rating between 1 and 5);

-- One feedback per completed donation (request).
alter table public.appreciations
  add constraint appreciations_request_id_key unique (request_id);

-- FK to blood_requests (deferred until after backfill so NOT NULL is safe).
alter table public.appreciations
  add constraint appreciations_request_id_fkey
  foreign key (request_id) references public.blood_requests(id) on delete cascade;

-- ── 2. Update RLS policies ──────────────────────────────────────────────────

-- Tighten INSERT: given_by_user_id must be the caller (enforced by RLS),
-- and the caller must not be the donor being rated.
drop policy if exists "Authenticated users can appreciate other donors"
  on public.appreciations;

create policy "Authenticated users can submit donation feedback"
  on public.appreciations for insert
  to authenticated
  with check (
    auth.uid() = given_by_user_id
    and auth.uid() <> donor_id
  );

-- ── 3. Replace give_appreciation with submit_donation_feedback ──────────────

drop function if exists public.give_appreciation(uuid);

create or replace function public.submit_donation_feedback(
  p_request_id uuid,
  p_star_rating integer,
  p_is_appreciated boolean
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

  -- Fetch the request.
  select * into v_request
  from public.blood_requests
  where id = p_request_id;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Request not found');
  end if;

  -- Only the seeker who created the request can leave feedback.
  if v_request.requester_id <> v_user_id then
    return jsonb_build_object('success', false, 'message', 'Only the request creator can submit feedback');
  end if;

  -- Request must have been fulfilled (a donation actually happened).
  if v_request.status <> 'fulfilled' then
    return jsonb_build_object('success', false, 'message', 'Request has not been fulfilled');
  end if;

  v_donor_id := v_request.fulfilled_by_donor_id;
  if v_donor_id is null then
    return jsonb_build_object('success', false, 'message', 'No donor recorded for this request');
  end if;

  -- Reject self-feedback.
  if v_donor_id = v_user_id then
    return jsonb_build_object('success', false, 'message', 'Cannot submit feedback for yourself');
  end if;

  -- Insert feedback (unique constraint on request_id prevents duplicates).
  insert into public.appreciations (donor_id, given_by_user_id, request_id, star_rating, is_appreciated)
  values (v_donor_id, v_user_id, p_request_id, p_star_rating, p_is_appreciated);

  return jsonb_build_object('success', true);
end;
$$;

revoke all on function public.submit_donation_feedback(uuid, integer, boolean) from public, anon;
grant execute on function public.submit_donation_feedback(uuid, integer, boolean) to authenticated;

-- ── 4. Replace get_donor_appreciation_stats with get_donor_feedback_stats ───

drop function if exists public.get_donor_appreciation_stats(uuid);

create or replace function public.get_donor_feedback_stats(p_donor_id uuid)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'appreciated_count', coalesce(v.appreciated_count, 0),
    'total_donations', coalesce(v.total_donations, 0),
    'appreciation_fraction',
      case when coalesce(v.total_donations, 0) > 0
        then round(coalesce(v.appreciated_count, 0)::numeric / v.total_donations, 4)
        else 0
      end
  )
  from (
    select
      (select count(*)::int
       from public.appreciations
       where donor_id = p_donor_id and is_appreciated = true
      ) as appreciated_count,
      (select total_donations from public.profiles where id = p_donor_id
      ) as total_donations
  ) v;
$$;

revoke all on function public.get_donor_feedback_stats(uuid) from public, anon;
grant execute on function public.get_donor_feedback_stats(uuid) to authenticated;

-- ── 5. Recreate profiles_public view with feedback fraction fields ──────────

drop view if exists public.profiles_public;

create or replace view public.profiles_public as
select
  p.id,
  p.name,
  p.blood_group,
  p.city,
  p.latitude,
  p.longitude,
  p.active_role,
  p.donor_classification,
  -- hemoglobin_level excluded (sensitive health data)
  -- health_disclosures excluded (sensitive health data)
  -- phone excluded (PII — only visible to profile owner)
  -- email excluded (PII — only visible to profile owner)
  -- fcm_token excluded (PII — only visible to profile owner)
  p.is_verified,
  p.is_top_donor,
  p.is_suspended,
  p.is_admin,
  p.last_donation_date,
  p.last_platelet_donation_date,
  p.can_donate_platelets,
  p.onboarding_complete,
  p.health_info_complete,
  p.profile_photo_url,
  p.bio,
  p.total_donations,
  p.donation_goal,
  coalesce(fb.appreciated_count, 0) as appreciated_count,
  case
    when coalesce(p.total_donations, 0) > 0
    then round(coalesce(fb.appreciated_count, 0)::numeric / p.total_donations, 4)
    else 0
  end as appreciation_fraction,
  p.show_last_donation_date,
  p.deleted_at,
  p.created_at,
  p.updated_at
from public.profiles p
left join (
  select donor_id, count(*)::int as appreciated_count
  from public.appreciations
  where is_appreciated = true
  group by donor_id
) fb on fb.donor_id = p.id;

grant select on public.profiles_public to authenticated;
