-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Donor-visible request history
--
-- Donation History (profile screen) reads blood_requests rows the donor
-- fulfilled. The base select policy only exposes active requests to non-
-- owners, so donors would lose access the moment a request is fulfilled.
-- This policy keeps requests the donor responded to / fulfilled readable.
-- ═══════════════════════════════════════════════════════════════════════════

create policy blood_requests_select_responder
  on public.blood_requests for select to authenticated using (
    exists (
      select 1 from public.request_responses rr
      where rr.request_id = public.blood_requests.id
        and rr.donor_id = auth.uid()
    )
    or fulfilled_by_donor_id = auth.uid()
  );
