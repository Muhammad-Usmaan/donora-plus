-- Exclude admin accounts from profiles_public view.
--
-- Admin accounts (is_admin = true) should never appear as donors/seekers
-- to other end users. This filter is centralized in the view so that all
-- 10+ cross-user queries (donor list, map, chat, requests, etc.) inherit
-- the exclusion automatically without per-screen patching.
--
-- The admin can still query the base profiles table directly for their
-- own profile or admin functions.

drop view if exists public.profiles_public;

create view public.profiles_public as
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
  p.phone,
  -- email excluded (PII — no cross-user feature needs it)
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
  coalesce(a.highest_milestone, 0) as highest_milestone,
  coalesce(a.total_achievements, 0) as total_achievements,
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
) fb on fb.donor_id = p.id
left join (
  select
    donor_id,
    max(milestone_count) filter (where achievement_type = 'milestone') as highest_milestone,
    count(*)::int as total_achievements
  from public.achievements
  group by donor_id
) a on a.donor_id = p.id
where not p.is_admin;

grant select on public.profiles_public to authenticated;

comment on view public.profiles_public is
  'Public profile view excluding admin accounts and sensitive data '
  '(hemoglobin_level, health_disclosures, email, fcm_token). '
  'Phone is included for the cross-user call feature. '
  'Admin accounts (is_admin = true) are filtered out so they never appear '
  'in donor lists, map markers, chat suggestions, or any cross-user surface. '
  'The owner and admins can query the base profiles table for full access.';
