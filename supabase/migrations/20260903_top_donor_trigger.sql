-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Auto-manage is_top_donor based on total_donations
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Design note: uses BEFORE UPDATE (not AFTER) so that NEW.is_top_donor is
-- set in-place before the row is written.  This avoids a recursive UPDATE
-- that would re-fire protect_privileged_profile_fields and get blocked.
--
-- Trigger ordering (PostgreSQL fires BEFORE triggers alphabetically):
--   trg_profiles_auto_top_donor  →  set_top_donor_status()       (1st)
--   trg_profiles_protect_flags   →  protect_privileged_profile_fields() (2nd)
--   trg_profiles_updated_at      →  set_updated_at()             (3rd)
--
-- Flow when confirm_blood_donation() increments total_donations:
--   1. set_top_donor_status: total_donations changed → set NEW.is_top_donor
--   2. protect_privileged_profile_fields: is_top_donor changed BUT
--      total_donations also changed → allow (auto-managed)
--   3. Row written with correct is_top_donor
--
-- Flow when client tries UPDATE profiles SET is_top_donor = true:
--   1. set_top_donor_status: total_donations unchanged → don't touch is_top_donor
--   2. protect_privileged_profile_fields: is_top_donor changed, total_donations
--      unchanged → REJECT
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Trigger function: auto-set is_top_donor when total_donations changes
create or replace function public.set_top_donor_status()
returns trigger language plpgsql as $$
begin
  if new.total_donations is distinct from old.total_donations then
    new.is_top_donor := (new.total_donations >= 5);
  end if;
  return new;
end;
$$;

-- 2. Attach trigger (named to fire BEFORE trg_profiles_protect_flags)
drop trigger if exists trg_profiles_auto_top_donor on public.profiles;
create trigger trg_profiles_auto_top_donor
  before update on public.profiles
  for each row
  execute function public.set_top_donor_status();

-- 3. Update protect_privileged_profile_fields:
--    Split the is_top_donor check from the other flags.
--    is_top_donor is now auto-managed when total_donations changes;
--    direct client writes to is_top_donor (without a total_donations change)
--    are still rejected.
create or replace function public.protect_privileged_profile_fields()
returns trigger language plpgsql as $$
begin
  -- Verified / suspended / admin: always protected
  if (new.is_verified     is distinct from old.is_verified
      or new.is_suspended is distinct from old.is_suspended
      or new.is_admin     is distinct from old.is_admin)
    and not public.is_admin()
    and coalesce(auth.role()::text, '') = 'authenticated'
  then
    raise exception 'Permission denied: moderation flags can only be changed by admins';
  end if;

  -- is_top_donor: auto-managed by trg_profiles_auto_top_donor when
  -- total_donations changes.  Block direct client manipulation.
  if (new.is_top_donor is distinct from old.is_top_donor
      and new.total_donations is not distinct from old.total_donations)
    and not public.is_admin()
    and coalesce(auth.role()::text, '') = 'authenticated'
  then
    raise exception 'Permission denied: is_top_donor is auto-managed based on total_donations';
  end if;

  return new;
end;
$$;
