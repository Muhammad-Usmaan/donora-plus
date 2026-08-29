-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Public donor response-count aggregate
--
-- The Donor Profile (seeker view) shows how many blood requests a donor
-- has responded to. RLS on request_responses only exposes a donor's own
-- rows (plus admin / requester views), so seekers cannot count another
-- donor's responses client-side. This SECURITY DEFINER aggregate exposes
-- ONLY the count — no response rows, requester identities, or content.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.donor_response_count(p_donor_id uuid)
returns integer
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::integer
  from public.request_responses
  where donor_id = p_donor_id;
$$;

-- Count-only helper: callable by signed-in users, nothing else.
revoke all on function public.donor_response_count(uuid) from public, anon;
grant execute on function public.donor_response_count(uuid) to authenticated;
