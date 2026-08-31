-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Push notification infrastructure
-- 1. device_tokens table: multi-device FCM token storage per user
-- 2. notification_preferences columns on profiles
-- ═══════════════════════════════════════════════════════════════════════════

-- ── device_tokens ──────────────────────────────────────────────────────────
-- One row per (user, device) pair. A user may have multiple devices
-- (phone + tablet, reinstalls, etc.). The token is the FCM registration
-- token for that specific device.
create table public.device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  token       text not null,
  platform    text check (platform in ('android','ios','web')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  -- Each token is unique per user (same token re-upserted → updated_at refresh).
  unique (user_id, token)
);

create index device_tokens_user_idx on public.device_tokens(user_id);
create index device_tokens_token_idx on public.device_tokens(token);

-- updated_at trigger
create trigger trg_device_tokens_updated_at
  before update on public.device_tokens
  for each row execute function public.set_updated_at();

-- RLS: users can only manage their own tokens.
alter table public.device_tokens enable row level security;

create policy device_tokens_select_own
  on public.device_tokens for select to authenticated
  using (user_id = auth.uid());

create policy device_tokens_upsert_own
  on public.device_tokens for insert to authenticated
  with check (user_id = auth.uid());

create policy device_tokens_update_own
  on public.device_tokens for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy device_tokens_delete_own
  on public.device_tokens for delete to authenticated
  using (user_id = auth.uid());

-- ── notification_preferences on profiles ───────────────────────────────────
-- Per-category boolean toggles. Defaults to true (opt-out model).
-- The edge function checks these before sending push notifications.
alter table public.profiles
  add column if not exists notify_new_requests    boolean not null default true,
  add column if not exists notify_messages        boolean not null default true,
  add column if not exists notify_request_updates boolean not null default true;

-- Migrate the legacy fcm_token column: any existing token gets inserted into
-- device_tokens so it isn't lost. This is a one-time migration.
insert into public.device_tokens (user_id, token, platform)
select id, fcm_token, null
from public.profiles
where fcm_token is not null and fcm_token <> ''
on conflict (user_id, token) do nothing;

-- ── Helper RPC: upsert device token ────────────────────────────────────────
-- Called by the Flutter client on login / token refresh.
-- Inserts or updates the token row; touches updated_at on conflict.
create or replace function public.upsert_device_token(
  p_token    text,
  p_platform text default null
)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.device_tokens (user_id, token, platform)
  values (auth.uid(), p_token, p_platform)
  on conflict (user_id, token)
  do update set platform = coalesce(excluded.platform, public.device_tokens.platform),
                updated_at = now();
end;
$$;

-- ── Helper RPC: delete device token (sign-out / disable push) ──────────────
create or replace function public.delete_device_token(p_token text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  delete from public.device_tokens
  where user_id = auth.uid() and token = p_token;
end;
$$;

-- ── Grant privileges ───────────────────────────────────────────────────────
grant all on public.device_tokens to anon, authenticated, service_role;
grant execute on function public.upsert_device_token to authenticated;
grant execute on function public.delete_device_token to authenticated;

comment on table public.device_tokens is 'FCM device tokens — one per (user, device) pair for push notifications';

-- ── Helper RPC: prepare notification ─────────────────────────────────────
-- Called by the Flutter client to create an in-app notification and
-- retrieve the recipient's device tokens for FCM delivery.
-- Checks the recipient's notification preferences before inserting.
create or replace function public.prepare_notification(
  p_recipient_id uuid,
  p_type         text,
  p_title        text,
  p_body         text,
  p_deep_link_id text default null
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_notify boolean;
  v_tokens text[];
  v_notif_id uuid;
begin
  -- 1. Check the recipient's preference for this notification type.
  select case p_type
    when 'urgent_request'    then notify_new_requests
    when 'new_request'       then notify_new_requests
    when 'new_message'       then notify_messages
    when 'request_accepted'  then notify_request_updates
    when 'request_fulfilled' then notify_request_updates
    when 'request_expired'   then notify_request_updates
    when 'verification_approved' then notify_request_updates
    else true
  end
  into v_notify
  from public.profiles where id = p_recipient_id;

  -- If the recipient has this category disabled, skip entirely.
  if not coalesce(v_notify, true) then
    return jsonb_build_object('sent', false, 'reason', 'preference_disabled');
  end if;

  -- 2. Insert the in-app notification row.
  insert into public.notifications (user_id, type, title, body, deep_link_id)
  values (p_recipient_id, p_type, p_title, p_body, p_deep_link_id)
  returning id into v_notif_id;

  -- 3. Collect the recipient's device tokens.
  select array_agg(token) into v_tokens
  from public.device_tokens
  where user_id = p_recipient_id;

  -- 4. Return tokens + metadata for the edge function.
  return jsonb_build_object(
    'sent', true,
    'notification_id', v_notif_id,
    'tokens', coalesce(v_tokens, array[]::text[]),
    'type', p_type,
    'title', p_title,
    'body', p_body,
    'deep_link_id', p_deep_link_id
  );
end;
$$;

grant execute on function public.prepare_notification to authenticated;
