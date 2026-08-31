-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Schema Fix (patient_name) & AI / User Chat History Persistence
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Ensure patient_name column exists on blood_requests
alter table public.blood_requests
  add column if not exists patient_name text not null default 'Patient';

-- 2. Update blood_requests status check constraint to include 'accepted'
alter table public.blood_requests
  drop constraint if exists blood_requests_status_check;

alter table public.blood_requests
  add constraint blood_requests_status_check
  check (status in ('active','accepted','fulfilled','cancelled','expired','closed'));

-- 3. Update conversations table to support AI chatbot conversations (participant_2_id nullable)
alter table public.conversations
  alter column participant_2_id drop not null;

alter table public.conversations
  drop constraint if exists conversations_check;

alter table public.conversations
  add constraint conversations_check
  check (participant_2_id is null or participant_1_id <> participant_2_id);

drop index if exists public.conversations_pair_key;
create unique index if not exists conversations_pair_key
  on public.conversations (least(participant_1_id, participant_2_id), greatest(participant_1_id, participant_2_id))
  where participant_2_id is not null;

create unique index if not exists conversations_ai_user_key
  on public.conversations (participant_1_id)
  where participant_2_id is null;

-- 4. Update messages table to support AI messages (sender_id nullable, longer content)
alter table public.messages
  alter column sender_id drop not null;

alter table public.messages
  drop constraint if exists messages_content_check;

alter table public.messages
  add constraint messages_content_check
  check (char_length(content) between 1 and 10000);

-- 5. Update RLS policies for conversations and messages
drop policy if exists conversations_select on public.conversations;
create policy conversations_select on public.conversations
  for select to authenticated
  using (
    participant_1_id = auth.uid()
    or participant_2_id = auth.uid()
    or public.is_admin()
  );

drop policy if exists conversations_insert on public.conversations;
create policy conversations_insert on public.conversations
  for insert to authenticated
  with check (
    participant_1_id = auth.uid()
    or participant_2_id = auth.uid()
  );

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
  for select to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id
        and (c.participant_1_id = auth.uid() or c.participant_2_id = auth.uid() or public.is_admin())
    )
  );

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
  for insert to authenticated
  with check (
    (sender_id = auth.uid() or sender_id is null)
    and exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id
        and (c.participant_1_id = auth.uid() or c.participant_2_id = auth.uid())
    )
  );

drop policy if exists messages_delete on public.messages;
create policy messages_delete on public.messages
  for delete to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id
        and (c.participant_1_id = auth.uid() or c.participant_2_id = auth.uid() or public.is_admin())
    )
  );
