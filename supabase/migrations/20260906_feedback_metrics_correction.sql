-- 20260906_feedback_metrics_correction.sql
-- Corrects the appreciation metrics:
--   - Denominator changes from total_donations to total_feedback_count
--     (count of feedback rows, not count of all donations)
--   - Removes appreciation_fraction (client computes display from raw counts)
--   - Adds average_star_rating (mean of star_rating across all feedback rows)
--
-- Previous design: appreciated_count / total_donations (donations without
-- feedback dragged the fraction down).  Corrected design: appreciated_count /
-- total_feedback_count (only measures the ratio among donors who received
-- feedback at all).  total_donations remains on the profiles table for
-- is_top_donor and other purposes but is no longer part of feedback stats.

-- ── 1. Replace get_donor_feedback_stats RPC ─────────────────────────────────

create or replace function public.get_donor_feedback_stats(p_donor_id uuid)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'appreciated_count', coalesce(v.appreciated_count, 0),
    'total_feedback_count', coalesce(v.total_feedback_count, 0),
    'average_star_rating', v.average_star_rating
  )
  from (
    select
      (select count(*)::int
       from public.appreciations
       where donor_id = p_donor_id and is_appreciated = true
      ) as appreciated_count,
      (select count(*)::int
       from public.appreciations
       where donor_id = p_donor_id
      ) as total_feedback_count,
      (select round(avg(star_rating)::numeric, 1)
       from public.appreciations
       where donor_id = p_donor_id
      ) as average_star_rating
  ) v;
$$;

revoke all on function public.get_donor_feedback_stats(uuid) from public, anon;
grant execute on function public.get_donor_feedback_stats(uuid) to authenticated;

-- ── 2. Recreate profiles_public with corrected feedback fields ──────────────

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
  coalesce(fb.total_feedback_count, 0) as total_feedback_count,
  fb.average_star_rating,
  p.show_last_donation_date,
  p.deleted_at,
  p.created_at,
  p.updated_at
from public.profiles p
left join (
  select
    donor_id,
    count(*) filter (where is_appreciated = true)::int as appreciated_count,
    count(*)::int as total_feedback_count,
    round(avg(star_rating)::numeric, 1) as average_star_rating
  from public.appreciations
  group by donor_id
) fb on fb.donor_id = p.id;

grant select on public.profiles_public to authenticated;
