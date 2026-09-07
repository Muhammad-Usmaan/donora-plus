-- Re-add phone to profiles_public view.
--
-- The 20260906_feedback_metrics_correction migration recreated profiles_public
-- AFTER 20260906_restore_phone_to_profiles_public had added phone, silently
-- overwriting the fix. This migration restores the phone column.
--
-- phone is needed for:
--   - Call Now button on the seeker-facing donor detail screen
--   - Call icon in the conversation app bar
-- Both features launch tel: URIs and require cross-user phone access.
-- email and fcm_token remain excluded (no cross-user feature needs them).

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

comment on view public.profiles_public is
  'Public profile view excluding sensitive health data (hemoglobin_level, health_disclosures) '
  'and PII (email, fcm_token). Phone is included for the cross-user call feature. '
  'Use for cross-user queries (donor list, donor detail, map, chat, requests). '
  'The owner and admins can query the base profiles table for full access.';
