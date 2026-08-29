-- Reverts 20260829_add_phone_verified: phone OTP verification was removed
-- from the app. Users now edit their phone number directly (no SMS code),
-- so the verification flag is no longer needed.
alter table public.profiles
  drop column if exists phone_verified;
