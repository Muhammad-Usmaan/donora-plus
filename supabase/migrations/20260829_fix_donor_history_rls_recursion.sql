-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Fix RLS infinite recursion on blood_requests
--
-- The blood_requests_select_responder policy (20260829_donor_request_history_rls)
-- queried request_responses, whose own select policy queries blood_requests.
-- Postgres raised "infinite recursion detected in policy" and every
-- authenticated SELECT on blood_requests failed with a 500 — the Requests
-- screen, Home lists and request detail all appeared empty/broken.
--
-- Standard fix: wrap the cross-table EXISTS in a SECURITY DEFINER function,
-- which bypasses RLS during evaluation and breaks the cycle.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.has_responded_to(req uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.request_responses rr
    where rr.request_id = req
      and rr.donor_id = auth.uid()
  );
$$;

revoke execute on function public.has_responded_to(uuid) from public, anon;
grant execute on function public.has_responded_to(uuid) to authenticated;

drop policy if exists blood_requests_select_responder
  on public.blood_requests;

create policy blood_requests_select_responder
  on public.blood_requests for select to authenticated using (
    public.has_responded_to(public.blood_requests.id)
    or fulfilled_by_donor_id = auth.uid()
  );
