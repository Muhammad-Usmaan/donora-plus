-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Phone Uniqueness, Profile Location & Helper RPC
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Add latitude and longitude to profiles table if they do not already exist
alter table public.profiles
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

-- 2. Ensure unique index on profiles(phone) for non-deleted rows
create unique index if not exists profiles_phone_key
  on public.profiles(phone) where phone is not null and phone <> '' and deleted_at is null;

-- 3. Create security definer RPC function to check if phone is registered
--    This allows anonymous / signing-up users to check uniqueness safely
--    without exposing any other profile attributes.
create or replace function public.is_phone_registered(check_phone text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  phone_found boolean;
begin
  if check_phone is null or check_phone = '' then
    return false;
  end if;

  select exists (
    select 1 from public.profiles
    where phone = check_phone and deleted_at is null
  ) into phone_found;

  return phone_found;
end;
$$;

-- Grant execution to anon, authenticated, and service_role
grant execute on function public.is_phone_registered(text) to anon, authenticated, service_role;
