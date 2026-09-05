-- Remove the allow_phone_contact column from blood_requests.
-- This field was a cosmetic display label ("In-app chat only" vs "Allow phone
-- call") with no backend logic differentiating behaviour — both options
-- resulted in identical in-app chat flow.  All communication goes through
-- in-app chat; the distinction is no longer needed.

alter table public.blood_requests
  drop column if exists allow_phone_contact;
