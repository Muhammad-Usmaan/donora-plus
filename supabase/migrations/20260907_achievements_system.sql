-- 20260907_achievements_system.sql
-- Achievements system: milestone-based (1, 5, 10, 25) and goal-based triggers,
-- with FCM notification support and public badge exposure on donor profiles.
--
-- Design:
--   - Milestone tiers are hardcoded as 1, 5, 10, 25 (hackathon scope).
--   - A single donation can trigger both a milestone AND a goal completion.
--   - Both achievement rows are inserted; both are returned to the client
--     so it can queue celebration screens sequentially.
--   - total_donations is combined across blood + platelet types.
--     The donation_type stored on the achievement is whichever request type
--     pushed the count over the threshold.

-- ── 1. Achievements table ────────────────────────────────────────────────────

create table if not exists public.achievements (
  id               uuid primary key default gen_random_uuid(),
  donor_id         uuid not null references public.profiles(id) on delete cascade,
  achievement_type text not null
    check (achievement_type in ('goal_reached', 'milestone')),
  donation_type    text
    check (donation_type is null or donation_type in ('whole_blood', 'platelets')),
  goal_value       integer,
  milestone_count  integer,
  achieved_at      timestamptz not null default now(),
  viewed           boolean not null default false
);

comment on table public.achievements is
  'Donor achievements: milestone tiers (1,5,10,25) and goal completions';

comment on column public.achievements.donation_type is
  'Donation type of the request that pushed total_donations over the threshold';

comment on column public.achievements.milestone_count is
  'Tier value for milestone achievements (1, 5, 10, 25); null for goal_reached';

comment on column public.achievements.goal_value is
  'Donor donation_goal at time of achievement; null for milestone';

-- Prevent duplicate milestone per tier per donor
create unique index idx_achievements_milestone_unique
  on public.achievements (donor_id, milestone_count)
  where achievement_type = 'milestone';

-- Prevent duplicate goal completion per distinct goal_value per donor
create unique index idx_achievements_goal_unique
  on public.achievements (donor_id, goal_value)
  where achievement_type = 'goal_reached';

-- Efficient donor-scoped queries (achievements screen, badge lookup)
create index idx_achievements_donor_id
  on public.achievements (donor_id);

-- RLS: achievements are private to the donor who earned them
alter table public.achievements enable row level security;

create policy "Users can view own achievements"
  on public.achievements for select to authenticated
  using (auth.uid() = donor_id);

-- No INSERT/UPDATE/DELETE policies needed:
--   confirm_blood_donation is SECURITY DEFINER (runs as postgres, bypasses RLS).
--   get_donor_achievement_badge is also SECURITY DEFINER.
--   Clients never write to this table directly.

-- ── 2. Add achievement notification preference ─────────────────────────────

alter table public.profiles
  add column if not exists notify_achievements boolean not null default true;

-- ── 3. Update prepare_notification to route achievement type ────────────────

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
    when 'achievement_unlocked'  then notify_achievements
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

-- ── 4. Rewrite confirm_blood_donation with achievement detection ─────────────
-- Changes from previous version:
--   - After incrementing total_donations, checks milestone tiers (1,5,10,25)
--   - Checks goal completion (total_donations >= donation_goal)
--   - Inserts achievement rows and collects notification payloads
--   - Returns achievements array so the client can send FCM per achievement

create or replace function public.confirm_blood_donation(
  p_request_id uuid,
  p_confirmed boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_request record;
  v_donor_id uuid;
  v_new_total integer;
  v_donation_goal integer;
  v_achievements jsonb[] := array[]::jsonb[];
  v_tier integer;
  v_milestone_exists boolean;
  v_goal_exists boolean;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'message', 'Not authenticated');
  end if;

  -- Get request and verify requester is the current user
  select * into v_request
  from public.blood_requests
  where id = p_request_id;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Request not found');
  end if;

  if v_request.requester_id <> v_user_id and not public.is_admin() then
    return jsonb_build_object('success', false, 'message', 'Only the request creator can confirm donation');
  end if;

  v_donor_id := v_request.fulfilled_by_donor_id;

  if p_confirmed then
    -- Mark request fulfilled
    update public.blood_requests
    set status = 'fulfilled',
        fulfilled_at = now(),
        updated_at = now()
    where id = p_request_id;

    -- Type-aware donation date recording + total increment
    if v_donor_id is not null then
      if v_request.donation_type = 'platelet' then
        -- Platelet donation: record platelet date only
        update public.profiles
        set last_platelet_donation_date = now(),
            total_donations = coalesce(total_donations, 0) + 1,
            updated_at = now()
        where id = v_donor_id;
      else
        -- Whole blood donation: record whole-blood date only
        update public.profiles
        set last_donation_date = now(),
            total_donations = coalesce(total_donations, 0) + 1,
            updated_at = now()
        where id = v_donor_id;
      end if;

      -- ── Achievement detection ──────────────────────────────────────────
      -- Read updated total and donor's current goal
      select total_donations, donation_goal
      into v_new_total, v_donation_goal
      from public.profiles
      where id = v_donor_id;

      -- Check milestone tiers (hardcoded for hackathon scope)
      foreach v_tier in array array[1, 5, 10, 25] loop
        if v_new_total = v_tier then
          -- Guard against duplicate (should not happen with unique index)
          select exists(
            select 1 from public.achievements
            where donor_id = v_donor_id
              and achievement_type = 'milestone'
              and milestone_count = v_tier
          ) into v_milestone_exists;

          if not v_milestone_exists then
            insert into public.achievements
              (donor_id, achievement_type, donation_type, milestone_count)
            values
              (v_donor_id, 'milestone', v_request.donation_type, v_tier);

            v_achievements := array_append(v_achievements, jsonb_build_object(
              'type', 'milestone',
              'milestone_count', v_tier,
              'donation_type', v_request.donation_type,
              'title', v_tier || ' Donations Reached!',
              'body', 'Congratulations! You have completed '
                || v_tier || ' donations.'
            ));
          end if;
        end if;
      end loop;

      -- Check goal completion (total_donations >= donation_goal, once per
      -- distinct goal_value — donor can earn a new one by raising their goal)
      if v_donation_goal is not null and v_new_total >= v_donation_goal then
        select exists(
          select 1 from public.achievements
          where donor_id = v_donor_id
            and achievement_type = 'goal_reached'
            and goal_value = v_donation_goal
        ) into v_goal_exists;

        if not v_goal_exists then
          insert into public.achievements
            (donor_id, achievement_type, donation_type, goal_value)
          values
            (v_donor_id, 'goal_reached', v_request.donation_type, v_donation_goal);

          v_achievements := array_append(v_achievements, jsonb_build_object(
            'type', 'goal_reached',
            'goal_value', v_donation_goal,
            'donation_type', v_request.donation_type,
            'title', 'Donation Goal Complete!',
            'body', 'You reached your goal of '
              || v_donation_goal || ' donations!'
          ));
        end if;
      end if;
    end if;

    return jsonb_build_object(
      'success', true,
      'status', 'fulfilled',
      'achievements', coalesce(v_achievements, array[]::jsonb[])
    );
  else
    -- Did not donate / Cancel match: release donor and reopen request
    update public.blood_requests
    set status = 'active',
        fulfilled_by_donor_id = null,
        updated_at = now()
    where id = p_request_id;

    if v_donor_id is not null then
      delete from public.request_responses
      where request_id = p_request_id and donor_id = v_donor_id;
    end if;

    return jsonb_build_object('success', true, 'status', 'active');
  end if;
end;
$$;

revoke all on function public.confirm_blood_donation(uuid, boolean) from public, anon;
grant execute on function public.confirm_blood_donation(uuid, boolean) to authenticated;

-- ── 5. Public achievement badge RPC ──────────────────────────────────────────
-- Returns a minimal summary suitable for seeker-facing donor profile badges.
-- Full achievement list stays private (RLS on achievements table).

create or replace function public.get_donor_achievement_badge(
  p_donor_id uuid
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_highest_milestone integer;
  v_total_achievements integer;
  v_latest_achieved_at timestamptz;
begin
  select
    max(milestone_count) filter (where achievement_type = 'milestone'),
    count(*)::int,
    max(achieved_at)
  into v_highest_milestone, v_total_achievements, v_latest_achieved_at
  from public.achievements
  where donor_id = p_donor_id;

  return jsonb_build_object(
    'highest_milestone', coalesce(v_highest_milestone, 0),
    'total_achievements', coalesce(v_total_achievements, 0),
    'latest_achieved_at', v_latest_achieved_at
  );
end;
$$;

revoke all on function public.get_donor_achievement_badge(uuid) from public, anon;
grant execute on function public.get_donor_achievement_badge(uuid) to authenticated;

-- ── 6. Recreate profiles_public with achievement badge trust signals ─────────
-- Adds highest_milestone and total_achievements as lightweight badge columns.
-- Full achievement details stay private via the get_donor_achievement_badge RPC.

drop view if exists public.profiles_public;

create view public.profiles_public as
select
  p.id,
  p.name,
  p.blood_group,
  p.city,
  p.latitude,
  p.longitude,
  p.active_role,
  p.donor_classification,
  -- hemoglobin_level excluded (sensitive health data)
  -- health_disclosures excluded (sensitive health data)
  p.phone,
  -- email excluded (PII — no cross-user feature needs it)
  -- fcm_token excluded (PII — only visible to profile owner)
  p.is_verified,
  p.is_top_donor,
  p.is_suspended,
  p.is_admin,
  p.last_donation_date,
  p.last_platelet_donation_date,
  p.can_donate_platelets,
  p.onboarding_complete,
  p.health_info_complete,
  p.profile_photo_url,
  p.bio,
  p.total_donations,
  p.donation_goal,
  coalesce(fb.appreciated_count, 0) as appreciated_count,
  coalesce(fb.total_feedback_count, 0) as total_feedback_count,
  fb.average_star_rating,
  coalesce(a.highest_milestone, 0) as highest_milestone,
  coalesce(a.total_achievements, 0) as total_achievements,
  p.show_last_donation_date,
  p.deleted_at,
  p.created_at,
  p.updated_at
from public.profiles p
left join (
  select
    donor_id,
    count(*) filter (where is_appreciated = true)::int as appreciated_count,
    count(*)::int as total_feedback_count,
    round(avg(star_rating)::numeric, 1) as average_star_rating
  from public.appreciations
  group by donor_id
) fb on fb.donor_id = p.id
left join (
  select
    donor_id,
    max(milestone_count) filter (where achievement_type = 'milestone')
      as highest_milestone,
    count(*)::int as total_achievements
  from public.achievements
  group by donor_id
) a on a.donor_id = p.id;

grant select on public.profiles_public to authenticated;

comment on view public.profiles_public is
  'Public profile view excluding sensitive health data (hemoglobin_level, health_disclosures) '
  'and PII (email, fcm_token). Phone is included for the cross-user call feature. '
  'Achievement badge columns (highest_milestone, total_achievements) are trust signals. '
  'Use for cross-user queries (donor list, donor detail, map, chat, requests). '
  'The owner and admins can query the base profiles table for full access.';
