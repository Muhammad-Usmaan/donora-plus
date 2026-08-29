-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Reason for request (UI redesign spec §2.3)
-- Adds the required `reason` category + optional free-text `reason_note`
-- to blood_requests. "Other" is the default so existing rows stay valid.
-- No new RLS policies: the columns follow the existing blood_requests
-- read/write rules (city-scoped reads, owner-only writes).
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.blood_requests
  add column if not exists reason text not null default 'other'
    check (reason in (
      'accident','surgery','pregnancy_childbirth',
      'cancer_chemotherapy','anemia_disorder','dengue_infection','other'
    )),
  add column if not exists reason_note text
    check (reason_note is null or char_length(reason_note) <= 60);

-- reason_note is only meaningful when reason = 'other'.
create or replace function public.enforce_reason_note_scope()
returns trigger language plpgsql as $$
begin
  if new.reason <> 'other' then
    new.reason_note = null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_blood_requests_reason_note on public.blood_requests;
create trigger trg_blood_requests_reason_note
  before insert or update on public.blood_requests
  for each row execute function public.enforce_reason_note_scope();
