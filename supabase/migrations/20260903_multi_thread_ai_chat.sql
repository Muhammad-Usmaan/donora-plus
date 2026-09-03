-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Multi-thread AI chatbot support
-- Allows multiple AI chatbot conversation threads per user (previously
-- limited to one), adds a title column for thread labels, and a
-- last_message_at column for sorting threads by recency.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Drop the unique index that enforced one AI conversation per user.
--    The partial index on (participant_1_id) WHERE participant_2_id IS NULL
--    prevented a second AI thread from being created.
drop index if exists public.conversations_ai_user_key;

-- 2. Add title column — used to label each thread in a "recent chats" list.
--    Nullable; defaults to null (client sets it, e.g. from first message).
alter table public.conversations
  add column if not exists title text;

-- 3. Add last_message_at column — tracks when the most recent message was
--    sent in each conversation, for sorting threads by recency.
alter table public.conversations
  add column if not exists last_message_at timestamptz;

-- 4. Backfill last_message_at from the latest existing message so that
--    existing conversations are immediately sortable.
update public.conversations c
set last_message_at = sub.latest
from (
  select conversation_id, max(created_at) as latest
  from public.messages
  group by conversation_id
) sub
where c.id = sub.conversation_id
  and c.last_message_at is null;

-- 5. Trigger: auto-update last_message_at whenever a message is inserted.
create or replace function public._fn_update_last_message_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  update public.conversations
  set last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists trg_messages_update_last_message_at on public.messages;
create trigger trg_messages_update_last_message_at
  after insert on public.messages
  for each row
  execute function public._fn_update_last_message_at();
