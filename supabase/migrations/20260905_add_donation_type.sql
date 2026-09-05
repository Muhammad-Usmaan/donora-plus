-- Add donation_type to blood_requests for Blood/Platelet feed segmentation.
--
-- This column was expected from a prior platelet schema migration but was
-- never actually created. This migration adds it now so the home screen
-- feed query can filter by donation type.
--
-- Default 'blood' preserves existing behaviour — every current row is a
-- whole-blood request. The CHECK constraint limits values to the two
-- supported types; extend the array if more types are added later.

-- 1. Add the column with a safe default so NOT NULL is satisfied for
--    existing rows without a backfill.
alter table public.blood_requests
  add column if not exists donation_type text not null default 'blood'
    check (donation_type in ('blood', 'platelet'));

-- 2. Composite index for the feed query pattern:
--    WHERE status = 'active' AND expires_at > now()
--    [AND donation_type = ?]  -- optional client-side filter
--    ORDER BY created_at DESC
--
--    A partial index on active rows keeps it small. The expires_at
--    filter uses now() which is not immutable, so it cannot appear
--    in the index predicate — it is applied as a heap filter after
--    the index scan, which is fine for the expected row counts.
create index if not exists blood_requests_feed_idx
  on public.blood_requests (created_at desc)
  where status = 'active';
