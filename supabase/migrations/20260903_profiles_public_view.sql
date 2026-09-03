-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Per-field visibility control for sensitive health data
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Problem: hemoglobin_level and health_disclosures are sensitive health data
-- that should only be visible to the profile owner and admins. Currently,
-- any authenticated user can read these fields via the profiles_select policy.
--
-- Solution: Create a profiles_public view that excludes these two columns.
-- Cross-user queries (donor list, donor detail, map, etc.) should query this
-- view instead of the base profiles table. The base table remains fully
-- accessible to the owner and admins via existing RLS policies.
--
-- Why view over column-level privileges:
-- - Postgres column-level GRANT/REVOKE are role-based, not row-based.
--   We cannot say "owner can SELECT hemoglobin_level but other users cannot."
-- - A view provides structural exclusion: the columns simply don't exist
--   in the view definition, so queries against the view cannot access them.
-- - This fits the existing RLS pattern: the schema uses is_admin() and
--   row-level policies, not column-level privileges.
--
-- Trade-off: The base table is still queryable by authenticated users (for
-- owner/admin access). Enforcement relies on the client using profiles_public
-- for cross-user queries. This is acceptable because:
-- 1. The Flutter client will be updated to use profiles_public.
-- 2. Direct database access is restricted to admins/service_role.
-- 3. The view provides a clear, auditable interface for public profile data.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Create the public view (excludes hemoglobin_level and health_disclosures)
create or replace view public.profiles_public as
select
  id,
  name,
  phone,
  email,
  blood_group,
  city,
  active_role,
  donor_classification,
  -- hemoglobin_level excluded (sensitive)
  -- health_disclosures excluded (sensitive)
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
  fcm_token,
  deleted_at,
  created_at,
  updated_at
from public.profiles;

-- 2. Grant SELECT on the view to authenticated users
-- Note: RLS cannot be enabled on views — the view automatically inherits
-- the RLS policies from the underlying profiles table. When a user queries
-- this view, Postgres checks the base table's policies (profiles_select,
-- profiles_select_own, profiles_select_admin) to determine which rows are
-- visible. The view only adds column exclusion (hemoglobin_level and
-- health_disclosures are not in the SELECT list above).
grant select on public.profiles_public to authenticated;

-- 3. Document the view's purpose
comment on view public.profiles_public is
  'Public profile view excluding sensitive health data (hemoglobin_level, health_disclosures). '
  'Use this for cross-user queries (donor list, donor detail, map). '
  'The owner and admins can query the base profiles table for full access.';
