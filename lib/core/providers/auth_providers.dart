import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase/supabase_client_provider.dart';
import '../../services/supabase/auth_service.dart';

// ── SupabaseAuthService provider ──────────────────────────────────────────────
final authServiceProvider = Provider<SupabaseAuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthService(client);
});

// ── Auth state stream provider ────────────────────────────────────────────────
/// Emits on every auth state change (sign-in, sign-out, token refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.authStateChanges;
});

// ── Current user provider ────────────────────────────────────────────────────
/// The currently signed-in user, or null if unauthenticated.
/// Automatically updates when the auth state changes.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
        data: (state) => state.session?.user,
      ) ??
      ref.read(authServiceProvider).currentUser;
});

// ── Active role provider ─────────────────────────────────────────────────────
/// The user's currently active role: 'seeker' or 'donor'.
/// Stored in SharedPreferences and synced across sessions.
/// Will be fully implemented when the role-selection feature is built.
final activeRoleProvider = StateProvider<String>((ref) => 'seeker');
