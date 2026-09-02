-- Add date_of_birth column and server-side age enforcement for donors.
--
-- date_of_birth is nullable so that existing seeker accounts are unaffected.
-- The trigger only fires when active_role = 'donor', requiring both a non-null
-- DOB and an age ≥ 18 years.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS date_of_birth date;

COMMENT ON COLUMN public.profiles.date_of_birth IS
  'Date of birth — used to compute donor age for eligibility (must be ≥ 18)';

-- Server-side enforcement: reject any insert/update that sets
-- active_role = 'donor' when the computed age is under 18 or DOB is NULL.
CREATE OR REPLACE FUNCTION public.enforce_donor_minimum_age()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.active_role = 'donor' THEN
    IF NEW.date_of_birth IS NULL THEN
      RAISE EXCEPTION 'Date of birth is required to register as a donor'
        USING ERRCODE = 'check_violation';
    END IF;
    IF age(NEW.date_of_birth) < make_interval(years => 18) THEN
      RAISE EXCEPTION 'You must be 18 or older to register as a donor'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_donor_age ON public.profiles;
CREATE TRIGGER trg_enforce_donor_age
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION enforce_donor_minimum_age();
