-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Request expiration logic
--
-- • Add planned_date (nullable timestamptz) for pre-planned (non-urgent)
--   requests — captures the date the donation is actually needed.
-- • Change expires_at default to 24h (urgent) and add a trigger that
--   sets expires_at automatically on insert/update:
--     - urgent  → created_at + 24 hours
--     - planned → end of planned_date day (23:59:59)
-- • Add a database function that marks active requests as expired once
--   their expires_at has passed. The cron schedule is handled by the
--   expire-stale-requests Edge Function (requires pg_cron for in-DB
--   scheduling, which is not enabled on this project).
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Add planned_date column
alter table public.blood_requests
  add column if not exists planned_date timestamptz;

-- 2. Change expires_at default from 72h to 24h
alter table public.blood_requests
  alter column expires_at set default (now() + interval '24 hours');

-- 3. Back-fill existing active rows: urgent rows that still have the old
--    72h default get reset to 24h from their created_at.
update public.blood_requests
set expires_at = created_at + interval '24 hours'
where is_urgent = true
  and status in ('active', 'accepted')
  and expires_at > created_at + interval '24 hours';

-- 4. Trigger function: auto-set expires_at based on urgency
create or replace function public.set_request_expiry()
returns trigger language plpgsql as $$
begin
  if new.is_urgent then
    -- Urgent: expires 24 hours after creation.
    new.expires_at = new.created_at + interval '24 hours';
  elsif new.planned_date is not null then
    -- Planned: expires at end of the planned day.
    new.expires_at = date_trunc('day', new.planned_date) + interval '1 day' - interval '1 second';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_request_expiry on public.blood_requests;
create trigger trg_set_request_expiry
  before insert or update on public.blood_requests
  for each row execute function public.set_request_expiry();

-- 5. Validation: non-urgent requests must have a planned_date
create or replace function public.enforce_planned_date_for_non_urgent()
returns trigger language plpgsql as $$
begin
  if not new.is_urgent and new.planned_date is null then
    raise exception 'planned_date is required for non-urgent requests'
      using hint = 'Set planned_date or mark the request as urgent.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_planned_date on public.blood_requests;
create trigger trg_enforce_planned_date
  before insert or update on public.blood_requests
  for each row execute function public.enforce_planned_date_for_non_urgent();

-- 6. Function to expire stale requests (called by cron / edge function)
create or replace function public.expire_stale_requests()
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_count integer;
begin
  update public.blood_requests
  set status = 'expired',
      updated_at = now()
  where status = 'active'
    and expires_at <= now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.expire_stale_requests() from public, anon;
grant execute on function public.expire_stale_requests() to authenticated;

-- 7. NOTE: pg_cron scheduling is intentionally omitted here because the
--    extension is not enabled on this project. Use the Edge Function
--    supabase/functions/expire-stale-requests instead:
--      supabase functions deploy expire-stale-requests
--      supabase functions schedule expire-stale-requests --cron "*/15 * * * *"
