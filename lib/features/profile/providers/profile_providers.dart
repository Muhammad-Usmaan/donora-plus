import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/route_names.dart';
import '../../../services/providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';
import '../../../services/supabase/storage_service_provider.dart';
import '../../home/providers/home_providers.dart';
import '../../chatbot/providers/chatbot_providers.dart';
import '../../requests/providers/requests_list_provider.dart';

// ── Logout action ─────────────────────────────────────────────────────────────

/// Signs the user out and navigates to the auth screen.
final logoutActionProvider = Provider<LogoutAction>((ref) {
  return LogoutAction(ref);
});

class LogoutAction {
  LogoutAction(this._ref);
  final Ref _ref;

  Future<void> call() async {
    // Stop targeting this device with push notifications before the
    // session goes away (the profile id is needed for the cleanup).
    final userId = _ref.read(currentUserProvider)?.id;
    try {
      await _ref.read(fcmServiceProvider).clearToken(userId: userId);
    } catch (_) {
      // Push cleanup is best-effort — never block sign-out.
    }

    try {
      final authService = _ref.read(authServiceProvider);
      await authService.signOut();
    } catch (_) {
      // Sign out locally even if server call fails.
    }

    // Clear user-scoped state so the next login starts fresh.
    _ref.invalidate(chatbotProvider);

    // Navigate to auth — the router redirect guard handles this
    // automatically once currentUser is null, but we go explicitly.
    final router = _ref.read(routerProvider);
    router.go(RoutePaths.auth);
  }
}

// ── Delete account action ─────────────────────────────────────────────────────

/// Permanently deletes the user's account and all associated data.
///
/// This is a destructive action — the UI MUST show a confirmation dialog
/// before calling this provider.
final deleteAccountActionProvider = Provider<DeleteAccountAction>((ref) {
  return DeleteAccountAction(ref);
});

class DeleteAccountAction {
  DeleteAccountAction(this._ref);
  final Ref _ref;

  /// Deletes the current user's account via the delete-user-account Edge
  /// Function, which removes the Auth user (fixing the orphan bug) and
  /// cleans up all related data.
  /// Returns true on success.
  Future<bool> call() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return false;

    try {
      // Best-effort: clear FCM device token before the session is gone.
      final userId = user.id;
      try {
        await _ref.read(fcmServiceProvider).clearToken(userId: userId);
      } catch (_) {
        // Push cleanup is best-effort — never block deletion.
      }

      final client = _ref.read(supabaseClientProvider);

      // Call the Edge Function which:
      //   1. Cleans up device_tokens, donor_reports, storage objects
      //   2. Deletes the profile row
      //   3. Deletes the Auth user via Admin API (the critical step)
      final response = await client.functions.invoke(
        'delete-user-account',
        body: {'userId': user.id},
      );

      if (response.data?['success'] != true) {
        return false;
      }

      // Sign out locally (the Edge Function already deleted the auth user,
      // but we need to clear the local session).
      final authService = _ref.read(authServiceProvider);
      await authService.signOut();

      // Clear user-scoped state so the next login starts fresh.
      _ref.invalidate(chatbotProvider);

      final router = _ref.read(routerProvider);
      router.go(RoutePaths.auth);
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Role switch ───────────────────────────────────────────────────────────────

/// Switches the user's active role and persists to Supabase.
final switchRoleActionProvider = Provider<SwitchRoleAction>((ref) {
  return SwitchRoleAction(ref);
});

class SwitchRoleAction {
  SwitchRoleAction(this._ref);
  final Ref _ref;

  Future<void> call(String newRole) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    // Update local state immediately.
    _ref.read(activeRoleProvider.notifier).state = newRole;

    try {
      final client = _ref.read(supabaseClientProvider);
      await client
          .from('profiles')
          .update({'active_role': newRole})
          .eq('id', user.id);
    } catch (_) {
      // Revert on failure.
      _ref.read(activeRoleProvider.notifier).state =
          newRole == 'seeker' ? 'donor' : 'seeker';
    }
  }
}

// ── Update profile field ─────────────────────────────────────────────────────

/// Updates one or more fields on the current user's profile row in Supabase.
///
/// Usage:
///   await ref.read(updateProfileFieldProvider)({'name': 'Alice'});
///   await ref.read(updateProfileFieldProvider)({'blood_group': 'A+', 'city': 'Lahore'});
final updateProfileFieldProvider =
    Provider<UpdateProfileFieldAction>((ref) {
  return UpdateProfileFieldAction(ref);
});

class UpdateProfileFieldAction {
  UpdateProfileFieldAction(this._ref);
  final Ref _ref;

  /// Updates the given [fields] in the profiles table and invalidates
  /// the cached profile so the UI refreshes automatically.
  /// Throws on Supabase errors (e.g. CHECK constraint violations).
  Future<void> call(Map<String, dynamic> fields) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw Exception('Not signed in');

    final client = _ref.read(supabaseClientProvider);
    await client.from('profiles').update(fields).eq('id', user.id);

    _ref.invalidate(userProfileProvider);
  }
}

// ── Change password ──────────────────────────────────────────────────────────

/// Changes the current user's password via Supabase Auth.
final changePasswordActionProvider =
    Provider<ChangePasswordAction>((ref) {
  return ChangePasswordAction(ref);
});

class ChangePasswordAction {
  ChangePasswordAction(this._ref);
  final Ref _ref;

  /// Updates the user's password to [newPassword].
  /// Throws if the passwords don't match, are too short, or the API call fails.
  Future<void> call(String newPassword, String confirmPassword) async {
    if (newPassword != confirmPassword) {
      throw Exception('Passwords do not match');
    }
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    final authService = _ref.read(authServiceProvider);
    await authService.updatePassword(newPassword);
  }
}

// ── Profile photo upload ─────────────────────────────────────────────────────

/// Picks an image from the gallery or camera, uploads it to Supabase
/// Storage, and updates the profile's `profile_photo_url` column.
final uploadProfilePhotoAction = Provider<UploadProfilePhotoAction>((ref) {
  return UploadProfilePhotoAction(ref);
});

class UploadProfilePhotoAction {
  UploadProfilePhotoAction(this._ref);
  final Ref _ref;

  static final _picker = ImagePicker();

  /// Picks and uploads a photo from [source].  Returns the new public
  /// URL on success, or null if the user cancelled the picker.
  /// Throws on upload or network errors.
  Future<String?> call(ImageSource source) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return null;

    final image = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image == null) return null; // user cancelled

    final bytes = await image.readAsBytes();
    final storage = _ref.read(storageServiceProvider);

    // Upload to profile-images/<user_id>/<uuid>.jpg
    final publicUrl = await storage.uploadFile(
      bucket: 'profile-images',
      path: user.id,
      bytes: bytes,
      contentType: 'image/jpeg',
    );

    // Persist the URL in the profiles table.
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('profiles')
        .update({'profile_photo_url': publicUrl})
        .eq('id', user.id);

    // Invalidate the cached profile so the UI refreshes.
    _ref.invalidate(userProfileProvider);

    return publicUrl;
  }
}

// ── Requested count ───────────────────────────────────────────────────────

/// Number of blood requests the current user has created (all statuses).
/// Backs the "Requested" stat tile on the profile screen — the counters
/// were relocated here from the removed Requests bottom-nav tab.
final myRequestCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('blood_requests')
      .select('id')
      .eq('requester_id', user.id);
  return data.length;
});

// ── My requests list (seeker profile) ───────────────────────────────────

/// All blood requests created by the current user, newest first.
///
/// Reuses [RequestListItem] from the requests feature so the profile card
/// can share the same status / expiry logic as the Requests screen.
final myRequestsListProvider = FutureProvider<List<RequestListItem>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return <RequestListItem>[];

  final client = ref.watch(supabaseClientProvider);
  const columns =
      'id, requester_id, blood_group, units_needed, hospital_name, city, '
      'is_urgent, status, created_at, expires_at, notes, reason, '
      'reason_note, planned_date, donation_type';

  final data = await client
      .from('blood_requests')
      .select(columns)
      .eq('requester_id', user.id)
      .order('created_at', ascending: false)
      .limit(100);

  return (data as List)
      .map((row) => RequestListItem.fromMap(row as Map<String, dynamic>))
      .toList();
});

// ── Donor feedback stats (appreciation fraction + star rating) ───────────────

/// Feedback stats for the current donor, fetched via RPC.
/// Returns {appreciated_count, total_feedback_count, average_star_rating}.
/// average_star_rating is null when no feedback has been received.
/// Returns null if the user is not signed in.
final feedbackStatsProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final result = await client.rpc(
    'get_donor_feedback_stats',
    params: {'p_donor_id': user.id},
  );

  if (result == null) {
    return {'appreciated_count': 0, 'total_feedback_count': 0, 'average_star_rating': null};
  }
  final map = result as Map<String, dynamic>;
  return {
    'appreciated_count': (map['appreciated_count'] as int?) ?? 0,
    'total_feedback_count': (map['total_feedback_count'] as int?) ?? 0,
    'average_star_rating': (map['average_star_rating'] as num?)?.toDouble(),
  };
});

// ── Donation eligibility (per-type next-eligible dates) ────────────────────

/// Per-type next-eligible dates returned by the
/// `get_next_donation_eligible_date` RPC (JSONB shape, migration 20260907).
class DonationEligibility {
  const DonationEligibility({
    required this.nextWholeBloodDate,
    required this.nextPlateletDate,
  });

  /// Next date the donor is eligible for whole blood.
  /// Null when the donor has never donated either type, or when both
  /// cooldowns have expired (immediately eligible).
  final DateTime? nextWholeBloodDate;

  /// Next date the donor is eligible for platelet donation.
  final DateTime? nextPlateletDate;

  factory DonationEligibility.fromMap(Map<String, dynamic> map) =>
      DonationEligibility(
        nextWholeBloodDate: map['next_whole_blood_date'] != null
            ? DateTime.tryParse(map['next_whole_blood_date'] as String)
            : null,
        nextPlateletDate: map['next_platelet_date'] != null
            ? DateTime.tryParse(map['next_platelet_date'] as String)
            : null,
      );
}

/// Next eligible dates per donation type for the current donor.
///
/// Returns null when the donor has never donated either type
/// (both next_*_date fields are null from the RPC).
final donationEligibilityProvider =
    FutureProvider<DonationEligibility?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final result = await client.rpc(
    'get_next_donation_eligible_date',
    params: {'p_donor_id': user.id},
  );

  if (result == null) return null;
  final map = result as Map<String, dynamic>;
  final eligibility = DonationEligibility.fromMap(map);
  // Both null means the donor has never donated either type.
  if (eligibility.nextWholeBloodDate == null &&
      eligibility.nextPlateletDate == null) {
    return null;
  }
  return eligibility;
});
