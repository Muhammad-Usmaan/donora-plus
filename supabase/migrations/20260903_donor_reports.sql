-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — donor_reports table + RLS
-- ═══════════════════════════════════════════════════════════════════════════
-- Allows authenticated users to report donors.  Reporters can insert and
-- read their own reports; admins can read and update all reports.
-- A unique partial constraint prevents duplicate pending reports per pair.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Table
create table public.donor_reports (
  id              uuid primary key default gen_random_uuid(),
  reporter_id     uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid not null references public.profiles(id) on delete cascade,
  reason          text not null check (char_length(reason) between 1 and 300),
  status          text not null default 'pending'
                    check (status in ('pending', 'reviewed', 'dismissed')),
  created_at      timestamptz not null default now()
);

-- 2. Prevent self-reports
alter table public.donor_reports
  add constraint donor_reports_no_self_report check (reporter_id <> reported_user_id);

-- 3. Prevent duplicate pending reports for the same reporter→reported pair.
--    Uses a unique partial index (only rows where status = 'pending').
create unique index uq_donor_reports_pending
  on public.donor_reports (reporter_id, reported_user_id)
  where status = 'pending';

-- 4. Enable RLS
alter table public.donor_reports enable row level security;

-- 5. Policies
--    INSERT: authenticated users can insert their own reports
create policy donor_reports_insert_own
  on public.donor_reports for insert to authenticated
  with check (reporter_id = auth.uid());

--    SELECT: reporters see only their own reports; admins see all
create policy donor_reports_select
  on public.donor_reports for select to authenticated
  using (reporter_id = auth.uid() or public.is_admin());

--    UPDATE: admins only
create policy donor_reports_update_admin
  on public.donor_reports for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());
