-- Re-add phone to profiles_public view.
--
-- The 20260904 migration removed phone (along with email and fcm_token)
-- as "PII not needed cross-user." However, the seeker-facing call feature
-- (Call Now on donor profile + call icon in conversation app bar) requires
-- cross-user phone access. The view is already gated by authenticated-only
-- GRANT plus underlying RLS on the base profiles table, so this is safe.
--
-- email and fcm_token remain excluded — they are not needed by any
-- cross-user feature.

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
  phone,
  -- email excluded (PII — no cross-user feature needs it)
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
  donation_goal,
  coalesce(ac.appreciation_count, 0) as appreciation_count,
  show_last_donation_date,
  deleted_at,
  created_at,
  updated_at
from public.profiles
left join (
  select donor_id, count(*) as appreciation_count
  from public.appreciations
  group by donor_id
) ac on ac.donor_id = id;

-- Re-grant (view was recreated, grants need refreshing)
grant select on public.profiles_public to authenticated;

comment on view public.profiles_public is
  'Public profile view excluding sensitive health data (hemoglobin_level, health_disclosures) '
  'and PII (email, fcm_token). Phone is included for the cross-user call feature. '
  'Use for cross-user queries (donor list, donor detail, map, chat, requests). '
  'The owner and admins can query the base profiles table for full access.';
