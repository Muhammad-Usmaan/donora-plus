-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Update profiles_public view: add location, remove PII
-- ═══════════════════════════════════════════════════════════════════════════
--
-- The original profiles_public view (20260903) excluded hemoglobin_level and
-- health_disclosures but still included phone, email, fcm_token, and was
-- missing latitude/longitude needed by the donor map and list.
--
-- This migration:
--   1. Adds latitude and longitude (needed for map pins and distance sorting)
--   2. Removes phone, email, and fcm_token (PII — not needed cross-user)
--
-- Sensitive fields excluded: hemoglobin_level, health_disclosures, phone,
-- email, fcm_token.
-- ═══════════════════════════════════════════════════════════════════════════

-- Must DROP first: CREATE OR REPLACE VIEW cannot remove columns from an
-- existing view, so we drop and recreate to apply the column changes.
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

-- Re-grant (view was recreated, grants may need refreshing)
grant select on public.profiles_public to authenticated;

comment on view public.profiles_public is
  'Public profile view excluding sensitive health data (hemoglobin_level, health_disclosures) '
  'and PII (phone, email, fcm_token). '
  'Use for cross-user queries (donor list, donor detail, map, chat, requests). '
  'The owner and admins can query the base profiles table for full access.';
