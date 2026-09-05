-- 20260906_profile_redesign_data.sql
-- Adds donation_goal, appreciations system, and next_donation_eligible_date RPC
-- for the profile screen redesign.

-- ── 1. donation_goal on profiles ─────────────────────────────────────────────

alter table public.profiles
  add column donation_goal integer;

alter table public.profiles
  add constraint profiles_donation_goal_check
  check (donation_goal is null or donation_goal > 0);

-- ── 2. appreciations table ───────────────────────────────────────────────────

create table if not exists public.appreciations (
  id uuid primary key default gen_random_uuid(),
  donor_id uuid not null references public.profiles(id) on delete cascade,
  given_by_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists idx_appreciations_donor_id
  on public.appreciations(donor_id);

-- RLS
alter table public.appreciations enable row level security;

-- Any authenticated user can view appreciations
create policy "Appreciations are viewable by authenticated users"
  on public.appreciations for select
  to authenticated
  using (true);

-- Any authenticated user can insert an appreciation for another donor (not themselves)
create policy "Authenticated users can appreciate other donors"
  on public.appreciations for insert
  to authenticated
  with check (
    auth.uid() = given_by_user_id
    and auth.uid() <> donor_id
  );

-- ── 3. Appreciation stats RPC (count + rank) ────────────────────────────────

create or replace function public.get_donor_appreciation_stats(p_donor_id uuid)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'count', coalesce(count_filter, 0),
    'rank', coalesce(rank_val, 0)
  )
  from (
    select
      (select count(*)::int
       from public.appreciations
       where donor_id = p_donor_id) as count_filter,
      (select rank_val from (
        select
          donor_id,
          count(*) as cnt,
          rank() over (order by count(*) desc) as rank_val
        from public.appreciations
        group by donor_id
      ) ranked where ranked.donor_id = p_donor_id) as rank_val
  ) stats;
$$;

-- ── 4. give_appreciation RPC ────────────────────────────────────────────────
-- Per-day abuse guard is enforced in PL/pgSQL (no expression index needed).

create or replace function public.give_appreciation(p_donor_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'message', 'Not authenticated');
  end if;

  if v_user_id = p_donor_id then
    return jsonb_build_object('success', false, 'message', 'Cannot appreciate yourself');
  end if;

  -- Verify donor exists
  if not exists (select 1 from public.profiles where id = p_donor_id) then
    return jsonb_build_object('success', false, 'message', 'Donor not found');
  end if;

  -- Per-day abuse guard: one appreciation per user per donor per day
  if exists (
    select 1 from public.appreciations
    where donor_id = p_donor_id
      and given_by_user_id = v_user_id
      and created_at >= current_date::timestamptz
  ) then
    return jsonb_build_object('success', false, 'message', 'You already appreciated this donor today');
  end if;

  insert into public.appreciations (donor_id, given_by_user_id)
  values (p_donor_id, v_user_id);

  return jsonb_build_object('success', true);
end;
$$;

-- ── 5. next_donation_eligible_date RPC ──────────────────────────────────────

create or replace function public.get_next_donation_eligible_date(p_donor_id uuid)
returns date
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_last_blood timestamptz;
  v_last_platelet timestamptz;
  v_blood_eligible date;
  v_platelet_eligible date;
begin
  select last_donation_date, last_platelet_donation_date
  into v_last_blood, v_last_platelet
  from public.profiles
  where id = p_donor_id;

  -- Never donated either type
  if v_last_blood is null and v_last_platelet is null then
    return null;
  end if;

  -- Blood: 90-day cooldown from last whole-blood donation
  if v_last_blood is not null then
    v_blood_eligible := (v_last_blood + interval '90 days')::date;
  else
    v_blood_eligible := null;
  end if;

  -- Platelet: 7-day cooldown from last platelet donation
  if v_last_platelet is not null then
    v_platelet_eligible := (v_last_platelet + interval '7 days')::date;
  else
    v_platelet_eligible := null;
  end if;

  -- Return whichever cooldown expires latest
  -- (donor must wait for both types to clear before being fully eligible)
  return greatest(
    coalesce(v_blood_eligible, '1970-01-01'::date),
    coalesce(v_platelet_eligible, '1970-01-01'::date)
  );
end;
$$;

-- ── 6. Recreate profiles_public view with donation_goal + appreciation_count ─

drop view if exists public.profiles_public;

create or replace view public.profiles_public as
select
  p.id,
  p.name,
  p.blood_group,
  p.city,
  p.latitude,
  p.longitude,
  p.active_role,
  p.donor_classification,
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
  coalesce(ac.appreciation_count, 0) as appreciation_count,
  p.show_last_donation_date,
  p.deleted_at,
  p.created_at,
  p.updated_at
from public.profiles p
left join (
  select donor_id, count(*) as appreciation_count
  from public.appreciations
  group by donor_id
) ac on ac.donor_id = p.id;
