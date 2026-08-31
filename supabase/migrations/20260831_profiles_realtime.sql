-- ═══════════════════════════════════════════════════════════════════════════
-- Enable Realtime replication for the profiles table
-- ═══════════════════════════════════════════════════════════════════════════
-- The userProfileProvider (home_providers.dart) subscribes to realtime changes
-- on the profiles table. Without this, the .stream() / channel subscription
-- fails with RealtimeSubscribeException (status: channelError).
--
-- RLS already allows authenticated users to SELECT their own row
-- (profiles_select policy: deleted_at is null), so no RLS changes needed.
-- ═══════════════════════════════════════════════════════════════════════════

do $$ begin
  alter publication supabase_realtime add table public.profiles;
exception when duplicate_object then null; end $$;
