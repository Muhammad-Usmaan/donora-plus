-- Track whether the profile's phone number was confirmed via OTP SMS.
-- Set by the app after Supabase Auth verifies the phone-change code;
-- phone numbers collected at signup start out unverified.
alter table public.profiles
  add column if not exists phone_verified boolean not null default false;
