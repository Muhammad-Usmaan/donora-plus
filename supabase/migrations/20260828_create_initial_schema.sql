-- ═══════════════════════════════════════════════════════════════════════════
-- Donora+ — Initial schema
-- Source of truth: SRS v1.0 §11 (Data Requirements & Schema)
-- Aligned with the Flutter client (lib/features/**/providers, lib/services/).
-- Tables: profiles, blood_requests, request_responses, conversations,
--         messages, notifications, verification_submissions, admin_audit_log
-- ═══════════════════════════════════════════════════════════════════════════

-- ── profiles ────────────────────────────────────────────────────────────────
-- One row per auth user (id = auth.users.id). Created client-side on signup
-- (upsert in auth_form_provider.dart), enriched during onboarding.
create table public.profiles (
  id                     uuid primary key references auth.users(id) on delete cascade,
  name                   text not null check (char_length(name) between 2 and 60),
  phone                  text check (phone is null or phone = '' or phone ~ '^\+92[0-9]{10}$'),
  email                  text check (email is null or email = '' or (email ~ '^[^@]+@[^@]+\.[^@]+$' and char_length(email) <= 100)),
  blood_group            text check (blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  city                   text,
  active_role            text not null default 'seeker' check (active_role in ('seeker','donor')),
  donor_classification   text check (donor_classification in ('volunteer','compensated')),
  hemoglobin_level       numeric(4,1) check (hemoglobin_level is null or hemoglobin_level between 4.0 and 20.0),
  health_disclosures     text[],
  is_verified            boolean not null default false,
  is_top_donor           boolean not null default false,
  is_suspended           boolean not null default false,
  is_admin               boolean not null default false,
  last_donation_date     timestamptz check (last_donation_date is null or last_donation_date <= now()),
  onboarding_complete    boolean not null default false,
  health_info_complete   boolean not null default false,
  profile_photo_url      text,
  bio                    text,
  total_donations        integer not null default 0,
  show_last_donation_date boolean not null default false,
  fcm_token              text,
  deleted_at             timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

-- Unique identifiers (only when set; soft-deleted rows excluded).
create unique index profiles_phone_key
  on public.profiles(phone) where phone is not null and phone <> '' and deleted_at is null;
create unique index profiles_email_key
  on public.profiles(email) where email is not null and email <> '' and deleted_at is null;

-- ── blood_requests ──────────────────────────────────────────────────────────
-- 'closed' is the client-side terminal status (request_detail_provider);
-- 'fulfilled'/'cancelled'/'expired' are the SRS lifecycle statuses.
create table public.blood_requests (
  id                     uuid primary key default gen_random_uuid(),
  requester_id           uuid not null references public.profiles(id) on delete cascade,
  blood_group            text not null check (blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  units_needed           integer not null check (units_needed between 1 and 10),
  hospital_name          text not null check (char_length(hospital_name) between 3 and 120),
  city                   text not null,
  notes                  text check (notes is null or char_length(notes) <= 300),
  is_urgent              boolean not null default false,
  status                 text not null default 'active'
                           check (status in ('active','fulfilled','cancelled','expired','closed')),
  allow_phone_contact    boolean not null default false,
  fulfilled_by_donor_id  uuid references public.profiles(id) on delete set null,
  fulfilled_at           timestamptz,
  cancelled_at           timestamptz,
  expires_at             timestamptz not null default (now() + interval '72 hours'),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

-- ── request_responses ───────────────────────────────────────────────────────
-- A donor tapping "I Can Help" (donor_detail_provider / request_detail_provider).
create table public.request_responses (
  id            uuid primary key default gen_random_uuid(),
  request_id    uuid not null references public.blood_requests(id) on delete cascade,
  donor_id      uuid not null references public.profiles(id) on delete cascade,
  message       text,
  responded_at  timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (request_id, donor_id)
);

-- ── conversations ───────────────────────────────────────────────────────────
-- 1:1 chat between any two users (chat_providers.dart).
create table public.conversations (
  id               uuid primary key default gen_random_uuid(),
  participant_1_id uuid not null references public.profiles(id) on delete cascade,
  participant_2_id uuid not null references public.profiles(id) on delete cascade,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (participant_1_id <> participant_2_id)
);
-- One conversation per user pair, regardless of participant order.
create unique index conversations_pair_key
  on public.conversations (least(participant_1_id, participant_2_id), greatest(participant_1_id, participant_2_id));

-- ── messages ────────────────────────────────────────────────────────────────
-- Streamed to the UI via Supabase Realtime (.stream in chat_providers.dart).
create table public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id       uuid not null references public.profiles(id) on delete cascade,
  content         text not null check (char_length(content) between 1 and 1000),
  is_read         boolean not null default false,
  created_at      timestamptz not null default now()
);

-- ── notifications ───────────────────────────────────────────────────────────
-- In-app notification center (notification_providers.dart). Rows are inserted
-- server-side (Edge Functions / service role) — no client INSERT policy.
create table public.notifications (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  type         text not null,
  title        text not null,
  body         text,
  deep_link_id text,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ── verification_submissions ────────────────────────────────────────────────
-- CNIC front/back + selfie review queue (SRS FR-VER-001/002).
create table public.verification_submissions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles(id) on delete cascade,
  cnic_front_url   text not null,
  cnic_back_url    text not null,
  selfie_url       text not null,
  status           text not null default 'pending' check (status in ('pending','approved','rejected')),
  rejection_reason text check (rejection_reason is null or char_length(rejection_reason) <= 500),
  reviewed_by      uuid references public.profiles(id) on delete set null,
  reviewed_at      timestamptz,
  submitted_at     timestamptz not null default now(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
-- BR-005: at most one pending-or-approved submission per user.
create unique index verification_submissions_one_active
  on public.verification_submissions(user_id) where status in ('pending','approved');

-- ── admin_audit_log ─────────────────────────────────────────────────────────
-- Immutable audit trail (SRS FR-ADM-004). The SRS "timestamp" column is
-- implemented as created_at for consistency with the app-wide trigger pattern.
create table public.admin_audit_log (
  id             uuid primary key default gen_random_uuid(),
  admin_id       uuid not null references public.profiles(id) on delete cascade,
  action         text not null check (action in
                   ('approve_verification','reject_verification','toggle_flag',
                    'edit_profile_field','suspend_user','unsuspend_user','delete_user')),
  target_user_id uuid references public.profiles(id) on delete set null,
  old_value      jsonb,
  new_value      jsonb,
  created_at     timestamptz not null default now()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- Functions & triggers
-- ═══════════════════════════════════════════════════════════════════════════

-- Maintain updated_at on every write.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at        before update on public.profiles                 for each row execute function public.set_updated_at();
create trigger trg_blood_requests_updated_at  before update on public.blood_requests           for each row execute function public.set_updated_at();
create trigger trg_request_responses_updated  before update on public.request_responses        for each row execute function public.set_updated_at();
create trigger trg_conversations_updated_at   before update on public.conversations            for each row execute function public.set_updated_at();
create trigger trg_notifications_updated_at   before update on public.notifications            for each row execute function public.set_updated_at();
create trigger trg_verifications_updated_at   before update on public.verification_submissions for each row execute function public.set_updated_at();

-- Admin check used by RLS policies (SECURITY DEFINER avoids recursion).
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false);
$$;

-- BR-002: a seeker may hold at most 3 simultaneously active requests.
-- Expired-but-unmarked requests no longer count toward the limit.
create or replace function public.enforce_max_active_requests()
returns trigger language plpgsql as $$
declare
  active_count integer;
begin
  if new.status = 'active' then
    select count(*) into active_count
    from public.blood_requests
    where requester_id = new.requester_id
      and status = 'active'
      and (expires_at is null or expires_at > now())
      and id <> new.id;
    if active_count >= 3 then
      raise exception 'You already have 3 active requests. Please cancel one first.';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_blood_requests_max_active
  before insert or update on public.blood_requests
  for each row execute function public.enforce_max_active_requests();

-- Security rule (SRS §27): users can never flip verification/moderation flags
-- on their own profile. Only admins (or the service role) may change them.
create or replace function public.protect_privileged_profile_fields()
returns trigger language plpgsql as $$
begin
  if (new.is_verified     is distinct from old.is_verified
      or new.is_top_donor is distinct from old.is_top_donor
      or new.is_suspended is distinct from old.is_suspended
      or new.is_admin     is distinct from old.is_admin)
    and not public.is_admin()
    and coalesce(auth.role()::text, '') = 'authenticated'
  then
    raise exception 'Permission denied: moderation flags can only be changed by admins';
  end if;
  return new;
end;
$$;

create trigger trg_profiles_protect_flags
  before update on public.profiles
  for each row execute function public.protect_privileged_profile_fields();

-- ═══════════════════════════════════════════════════════════════════════════
-- Indexes (SRS §23 / Dev Plan Phase 1)
-- ═══════════════════════════════════════════════════════════════════════════

create index profiles_blood_group_idx    on public.profiles(blood_group);
create index profiles_city_idx           on public.profiles(city);
create index profiles_active_role_idx    on public.profiles(active_role);
create index profiles_verified_donor_idx on public.profiles(active_role, is_verified) where is_verified and deleted_at is null;
create index blood_requests_status_idx   on public.blood_requests(status);
create index blood_requests_group_idx    on public.blood_requests(blood_group);
create index blood_requests_requester_idx on public.blood_requests(requester_id);
create index blood_requests_created_idx  on public.blood_requests(created_at desc);
create index request_responses_request_idx on public.request_responses(request_id);
create index request_responses_donor_idx   on public.request_responses(donor_id);
create index conversations_updated_idx   on public.conversations(updated_at desc);
create index messages_conversation_idx   on public.messages(conversation_id, created_at);
create index notifications_user_idx      on public.notifications(user_id, is_read);
create index verification_status_idx     on public.verification_submissions(status);

-- ═══════════════════════════════════════════════════════════════════════════
-- Row Level Security (SRS §11.2, §16)
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.profiles                 enable row level security;
alter table public.blood_requests           enable row level security;
alter table public.request_responses        enable row level security;
alter table public.conversations            enable row level security;
alter table public.messages                 enable row level security;
alter table public.notifications            enable row level security;
alter table public.verification_submissions enable row level security;
alter table public.admin_audit_log          enable row level security;

-- profiles ─ readable for discovery/chat (non-deleted rows); writable own-row only.
-- NOTE: donor discovery requires authenticated users to read other profiles
-- (map_providers / donor_detail_provider select them directly), so per-field
-- hiding (hemoglobin, health_disclosures) is deferred post-MVP.
create policy profiles_select         on public.profiles for select to authenticated using (deleted_at is null);
create policy profiles_select_admin   on public.profiles for select to authenticated using (public.is_admin());
create policy profiles_insert_own     on public.profiles for insert to authenticated with check (id = auth.uid());
create policy profiles_update_own     on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_update_admin   on public.profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy profiles_delete_own     on public.profiles for delete to authenticated using (id = auth.uid());
create policy profiles_delete_admin   on public.profiles for delete to authenticated using (public.is_admin());

-- blood_requests ─ active & unexpired visible to all authenticated users
-- (RLS-level 72h expiry per BR-006); full history visible to owner and admins.
create policy blood_requests_select       on public.blood_requests for select to authenticated using (
  requester_id = auth.uid()
  or public.is_admin()
  or (status = 'active' and expires_at > now())
);
create policy blood_requests_insert_own   on public.blood_requests for insert to authenticated with check (requester_id = auth.uid());
create policy blood_requests_update_own   on public.blood_requests for update to authenticated using (requester_id = auth.uid()) with check (requester_id = auth.uid());
create policy blood_requests_update_admin on public.blood_requests for update to authenticated using (public.is_admin()) with check (true);

-- request_responses ─ donors see their own; seekers see responses to their requests.
create policy request_responses_select     on public.request_responses for select to authenticated using (
  donor_id = auth.uid()
  or public.is_admin()
  or exists (select 1 from public.blood_requests r
             where r.id = request_id and r.requester_id = auth.uid())
);
create policy request_responses_insert_own on public.request_responses for insert to authenticated with check (donor_id = auth.uid());

-- conversations ─ participants only.
create policy conversations_select  on public.conversations for select to authenticated using (
  participant_1_id = auth.uid() or participant_2_id = auth.uid() or public.is_admin()
);
create policy conversations_insert  on public.conversations for insert to authenticated with check (
  participant_1_id = auth.uid() or participant_2_id = auth.uid()
);
create policy conversations_update  on public.conversations for update to authenticated using (
  participant_1_id = auth.uid() or participant_2_id = auth.uid()
) with check (
  participant_1_id = auth.uid() or participant_2_id = auth.uid()
);

-- messages ─ conversation participants only (covers realtime subscriptions too).
create policy messages_select on public.messages for select to authenticated using (
  exists (select 1 from public.conversations c
          where c.id = conversation_id
            and (c.participant_1_id = auth.uid() or c.participant_2_id = auth.uid() or public.is_admin()))
);
create policy messages_insert on public.messages for insert to authenticated with check (
  sender_id = auth.uid()
  and exists (select 1 from public.conversations c
              where c.id = conversation_id
                and (c.participant_1_id = auth.uid() or c.participant_2_id = auth.uid()))
);
create policy messages_update on public.messages for update to authenticated using (
  exists (select 1 from public.conversations c
          where c.id = conversation_id
            and (c.participant_1_id = auth.uid() or c.participant_2_id = auth.uid()))
) with check (
  exists (select 1 from public.conversations c
          where c.id = conversation_id
            and (c.participant_1_id = auth.uid() or c.participant_2_id = auth.uid()))
);

-- notifications ─ own rows only; inserts happen server-side (service role).
create policy notifications_select_own on public.notifications for select to authenticated using (user_id = auth.uid());
create policy notifications_update_own on public.notifications for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- verification_submissions ─ own submissions for donors; full access for admins.
create policy verifications_select_own   on public.verification_submissions for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy verifications_insert_own   on public.verification_submissions for insert to authenticated with check (user_id = auth.uid());
create policy verifications_update_admin on public.verification_submissions for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- admin_audit_log ─ read-only for admins; written by the service role only.
create policy audit_log_select_admin on public.admin_audit_log for select to authenticated using (public.is_admin());

-- ═══════════════════════════════════════════════════════════════════════════
-- Storage buckets (SRS FR-SEC-005: verification docs are private)
-- ═══════════════════════════════════════════════════════════════════════════

insert into storage.buckets (id, name, public)
values ('profile-images', 'profile-images', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('verifications', 'verifications', false)
on conflict (id) do nothing;

-- Objects are stored under "<bucket>/<user_id>/<uuid>.<ext>" (storage_service.dart).

create policy profile_images_public_read
  on storage.objects for select to public
  using (bucket_id = 'profile-images');

create policy users_upload_own_profile_images
  on storage.objects for insert to authenticated
  with check (bucket_id = 'profile-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy users_upload_own_verification_docs
  on storage.objects for insert to authenticated
  with check (bucket_id = 'verifications' and (storage.foldername(name))[1] = auth.uid()::text);

create policy users_read_own_verification_docs
  on storage.objects for select to authenticated
  using (bucket_id = 'verifications' and (storage.foldername(name))[1] = auth.uid()::text);

create policy admins_read_verification_docs
  on storage.objects for select to authenticated
  using (bucket_id = 'verifications' and public.is_admin());

create policy users_delete_own_storage_objects
  on storage.objects for delete to authenticated
  using (bucket_id in ('profile-images','verifications')
         and (storage.foldername(name))[1] = auth.uid()::text);

-- ═══════════════════════════════════════════════════════════════════════════
-- Realtime — tables streamed by the app (chat messages, urgent requests)
-- ═══════════════════════════════════════════════════════════════════════════

do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; end $$;

do $$ begin
  alter publication supabase_realtime add table public.conversations;
exception when duplicate_object then null; end $$;

do $$ begin
  alter publication supabase_realtime add table public.blood_requests;
exception when duplicate_object then null; end $$;

do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null; end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- Privileges — ensure the client roles can reach everything (idempotent)
-- ═══════════════════════════════════════════════════════════════════════════

grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
grant execute on all functions in schema public to anon, authenticated, service_role;

comment on table public.profiles                 is 'User profiles — one per auth user (SRS §11.1)';
comment on table public.blood_requests           is 'Blood donation requests with lifecycle status (SRS FR-MATCH-001/004)';
comment on table public.request_responses        is 'Donor "I Can Help" responses to blood requests';
comment on table public.conversations            is '1:1 chat conversations between users';
comment on table public.messages                 is 'Chat messages, streamed via Supabase Realtime';
comment on table public.notifications            is 'In-app notifications (inserted server-side only)';
comment on table public.verification_submissions is 'CNIC/selfie verification queue for admin review (SRS FR-VER)';
comment on table public.admin_audit_log          is 'Immutable admin action audit trail (SRS FR-ADM-004)';
