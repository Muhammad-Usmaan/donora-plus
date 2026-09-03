-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Additional notification preference toggles
-- Adds per-category columns for verification and top-donor notifications
-- so they are server-synced like the existing three toggles.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── New notification_preferences columns on profiles ───────────────────────
-- Per-category boolean toggles, matching the existing opt-out pattern
-- (notify_new_requests, notify_messages, notify_request_updates).
alter table public.profiles
  add column if not exists notify_verification_updates boolean not null default true,
  add column if not exists notify_top_donor_updates    boolean not null default true;

-- ── Update prepare_notification() RPC ─────────────────────────────────────
-- Route verification_approved → notify_verification_updates (was notify_request_updates)
-- Route top_donor → notify_top_donor_updates (new case)
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
    when 'urgent_request'        then notify_new_requests
    when 'new_request'           then notify_new_requests
    when 'new_message'           then notify_messages
    when 'request_accepted'      then notify_request_updates
    when 'request_fulfilled'     then notify_request_updates
    when 'request_expired'       then notify_request_updates
    when 'verification_approved' then notify_verification_updates
    when 'top_donor'             then notify_top_donor_updates
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
