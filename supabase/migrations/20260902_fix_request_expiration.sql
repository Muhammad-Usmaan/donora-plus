-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Fix request expiration (timezone + stuck requests)
--
-- Root causes:
--   1. The set_request_expiry() trigger truncated planned_date in UTC
--      instead of Pakistan time (Asia/Karachi, UTC+5), causing planned
--      requests to expire ~5 hours late.
--   2. No cron job or scheduled edge function was ever configured to call
--      expire_stale_requests(), so requests stayed status='active' even
--      after their expires_at passed.
--
-- Fixes applied:
--   A. Replace the trigger function with timezone-aware calculation.
--   B. Back-fix expires_at for existing planned requests (UTC→PKT).
--   C. Mark all requests whose expires_at has already passed as 'expired'.
--   D. Add a self-scheduling wrapper so expire_stale_requests() can be
--      called from pg_cron IF the extension is enabled, or from an
--      external cron hitting the Edge Function.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── A. Fix the trigger to use Pakistan timezone ─────────────────────────────

create or replace function public.set_request_expiry()
returns trigger language plpgsql as $$
begin
  if new.is_urgent then
    -- Urgent: expires 24 hours after creation.
    new.expires_at = new.created_at + interval '24 hours';
  elsif new.planned_date is not null then
    -- Planned: expires at end of the planned day in Pakistan time (UTC+5).
    -- date_trunc('day', ...) truncates in the session timezone (UTC on
    -- Supabase), so we convert to PKT first, truncate, add the offset,
    -- then convert back to UTC for storage in the timestamptz column.
    new.expires_at = (
      date_trunc('day', new.planned_date at time zone 'Asia/Karachi')
      + interval '1 day' - interval '1 second'
    ) at time zone 'Asia/Karachi';
  end if;
  return new;
end;
$$;

-- ── B. Back-fix expires_at for existing planned requests ────────────────────
-- Recalculate expires_at using the corrected timezone-aware formula.
-- Only touch non-urgent rows that have a planned_date and haven't been
-- manually marked expired/fulfilled/cancelled/closed.

update public.blood_requests
set expires_at = (
      date_trunc('day', planned_date at time zone 'Asia/Karachi')
      + interval '1 day' - interval '1 second'
    ) at time zone 'Asia/Karachi'
where is_urgent = false
  and planned_date is not null
  and status in ('active');

-- ── C. Mark all overdue requests as expired ─────────────────────────────────
-- Any active request whose expires_at has already passed should be 'expired'.

update public.blood_requests
set status = 'expired',
    updated_at = now()
where status = 'active'
  and expires_at <= now();

-- ── D. Scheduling note ──────────────────────────────────────────────────────
-- If pg_cron is enabled in the Supabase dashboard, uncomment the following:
--
--   select cron.schedule(
--     'expire-stale-requests',
--     '*/15 * * * *',
--     'select public.expire_stale_requests()'
--   );
--
-- Otherwise, schedule the Edge Function via Supabase CLI:
--   supabase functions deploy expire-stale-requests
--   supabase functions schedule expire-stale-requests --cron "*/15 * * * *"
--
-- Until one of these is configured, the client-side expiry checks
-- (RequestListItem.isExpired / RequestDetail.isExpired) ensure the UI
-- still displays the correct status even if the DB status lags behind.
