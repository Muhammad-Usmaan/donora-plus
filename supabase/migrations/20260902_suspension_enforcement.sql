-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Suspension enforcement
-- Adds a SECURITY DEFINER helper and RLS policies that block suspended
-- users from performing key write actions server-side.
-- ═══════════════════════════════════════════════════════════════════════════

-- SECURITY DEFINER function to check if the current user is suspended.
-- Used by RLS policies to avoid direct table access recursion.
create or replace function public.is_user_suspended()
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce(
    (select p.is_suspended from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

-- Revoke public execute; only authenticated role should use this.
revoke execute on function public.is_user_suspended() from anon;
revoke execute on function public.is_user_suspended() from authenticated;
grant execute on function public.is_user_suspended() to authenticated;

-- ── blood_requests ──────────────────────────────────────────────────────────
-- Drop and recreate insert/update policies to block suspended users.
drop policy if exists blood_requests_insert_own on public.blood_requests;
drop policy if exists blood_requests_update_own on public.blood_requests;

create policy blood_requests_insert_own on public.blood_requests
  for insert to authenticated
  with check (requester_id = auth.uid() and not public.is_user_suspended());

create policy blood_requests_update_own on public.blood_requests
  for update to authenticated
  using (requester_id = auth.uid() and not public.is_user_suspended())
  with check (requester_id = auth.uid() and not public.is_user_suspended());

-- ── request_responses ───────────────────────────────────────────────────────
-- Suspended donors cannot respond to new requests.
drop policy if exists request_responses_insert_own on public.request_responses;

create policy request_responses_insert_own on public.request_responses
  for insert to authenticated
  with check (donor_id = auth.uid() and not public.is_user_suspended());

-- ── conversations ───────────────────────────────────────────────────────────
-- Suspended users cannot start new conversations.
drop policy if exists conversations_insert on public.conversations;

create policy conversations_insert on public.conversations
  for insert to authenticated
  with check (
    (participant_1_id = auth.uid() or participant_2_id = auth.uid())
    and not public.is_user_suspended()
  );

-- ── messages ────────────────────────────────────────────────────────────────
-- Suspended users cannot send new messages.
drop policy if exists messages_insert on public.messages;

create policy messages_insert on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and not public.is_user_suspended()
    and exists (select 1 from public.conversations c
                where c.id = conversation_id
                  and (c.participant_1_id = auth.uid() or c.participant_2_id = auth.uid()))
  );
