-- ═══════════════════════════════════════════════════════════════════════════
-- Fix: chat message read-state tracking
--
-- Root cause: client used .eq('sender_id', 'neq.<uuid>') which generates
--   sender_id = 'neq.<uuid>' (literal string, matches zero rows).
--   Fixed client-side to use .neq('sender_id', uuid).
--
-- This migration adds:
--   A. Tightened RLS on messages UPDATE — only the recipient can mark read
--   B. get_unread_message_count() RPC — total unread messages for caller
--   C. get_unread_notification_count() RPC — total unread notifications
--   D. Partial index on messages for efficient unread queries
-- ═══════════════════════════════════════════════════════════════════════════

-- ── A. Tighten messages UPDATE policy ──────────────────────────────────────
-- Old policy allowed any conversation participant to update any message.
-- New policy restricts to the RECIPIENT only (sender_id != auth.uid()),
-- so users can only mark messages they received as read, not their own.

drop policy if exists messages_update on public.messages;
create policy messages_update on public.messages for update to authenticated
using (
  sender_id != auth.uid()
  and exists (
    select 1 from public.conversations c
    where c.id = conversation_id
      and (c.participant_1_id = auth.uid() or c.participant_2_id = auth.uid())
  )
)
with check (
  sender_id != auth.uid()
  and exists (
    select 1 from public.conversations c
    where c.id = conversation_id
      and (c.participant_1_id = auth.uid() or c.participant_2_id = auth.uid())
  )
);

-- ── B. Unread message count RPC ────────────────────────────────────────────
-- Returns total unread messages received by the caller across all
-- conversations. Efficient enough for polling or realtime use.

create or replace function public.get_unread_message_count()
returns bigint
language sql security definer set search_path = public
as $$
  select count(*)
  from public.messages m
  where m.is_read = false
    and m.sender_id != auth.uid()
    and exists (
      select 1 from public.conversations c
      where c.id = m.conversation_id
        and (c.participant_1_id = auth.uid() or c.participant_2_id = auth.uid())
    );
$$;

revoke execute on function public.get_unread_message_count() from anon;
revoke execute on function public.get_unread_message_count() from authenticated;
grant execute on function public.get_unread_message_count() to authenticated;

-- ── C. Unread notification count RPC ───────────────────────────────────────
-- Returns total unread notifications for the caller.

create or replace function public.get_unread_notification_count()
returns bigint
language sql security definer set search_path = public
as $$
  select count(*)
  from public.notifications
  where user_id = auth.uid()
    and is_read = false;
$$;

revoke execute on function public.get_unread_notification_count() from anon;
revoke execute on function public.get_unread_notification_count() from authenticated;
grant execute on function public.get_unread_notification_count() to authenticated;

-- ── D. Partial index for unread messages ───────────────────────────────────
-- Speeds up the unread count query and per-conversation unread filtering.

create index if not exists messages_unread_idx
  on public.messages (conversation_id, sender_id)
  where is_read = false;
