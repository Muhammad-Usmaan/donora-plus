import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase/supabase_client_provider.dart';

/// User preferences for push and in-app notifications.
///
/// Mirrors the notification types used by the `notifications` table and FCM
/// data payloads (`type` + `deep_link_id`).
class NotificationSettings {
  const NotificationSettings({
    this.pushEnabled = true,
    this.urgentRequests = true,
    this.newMessages = true,
    this.verificationUpdates = true,
    this.topDonorUpdates = true,
  });

  /// Master toggle — when off, the device FCM token is removed from the
  /// profile row so the backend stops targeting this device.
  final bool pushEnabled;

  /// Urgent blood requests near the user.
  final bool urgentRequests;

  /// New chat messages.
  final bool newMessages;

  /// Verification status changes (approved/rejected).
  final bool verificationUpdates;

  /// Top donor awards.
  final bool topDonorUpdates;

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? urgentRequests,
    bool? newMessages,
    bool? verificationUpdates,
    bool? topDonorUpdates,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      urgentRequests: urgentRequests ?? this.urgentRequests,
      newMessages: newMessages ?? this.newMessages,
      verificationUpdates: verificationUpdates ?? this.verificationUpdates,
      topDonorUpdates: topDonorUpdates ?? this.topDonorUpdates,
    );
  }
}

/// Persists [NotificationSettings] in SharedPreferences (local cache) and
/// syncs the server-side columns on `profiles` so the edge functions can
/// honour per-category preferences when sending push notifications.
///
/// Column mapping:
///   pushEnabled        → controls FCM token registration (no DB column)
///   urgentRequests     → profiles.notify_new_requests
///   newMessages        → profiles.notify_messages
///   verificationUpdates → profiles.notify_verification_updates
///   topDonorUpdates    → profiles.notify_top_donor_updates
class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier(this._prefs, this._supabase)
      : super(const NotificationSettings()) {
    _load();
    _loadFromServer();
  }

  final SharedPreferences _prefs;
  final SupabaseClient _supabase;

  static const _keyPush = 'notif.push_enabled';
  static const _keyUrgent = 'notif.urgent_requests';
  static const _keyMessages = 'notif.new_messages';

  void _load() {
    state = NotificationSettings(
      pushEnabled: _prefs.getBool(_keyPush) ?? true,
      urgentRequests: _prefs.getBool(_keyUrgent) ?? true,
      newMessages: _prefs.getBool(_keyMessages) ?? true,
    );
  }

  /// Fetches the user's notification preferences from the `profiles` table
  /// and merges them into the local state. Server values take precedence.
  Future<void> _loadFromServer() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final row = await _supabase
          .from('profiles')
          .select(
              'notify_new_requests, notify_messages, notify_request_updates, '
              'notify_verification_updates, notify_top_donor_updates')
          .eq('id', userId)
          .maybeSingle();

      if (row == null) return;

      final serverNewRequests =
          row['notify_new_requests'] as bool? ?? state.urgentRequests;
      final serverMessages =
          row['notify_messages'] as bool? ?? state.newMessages;
      final serverVerification =
          row['notify_verification_updates'] as bool? ?? state.verificationUpdates;
      final serverTopDonor =
          row['notify_top_donor_updates'] as bool? ?? state.topDonorUpdates;

      state = state.copyWith(
        urgentRequests: serverNewRequests,
        newMessages: serverMessages,
        verificationUpdates: serverVerification,
        topDonorUpdates: serverTopDonor,
      );

      // Cache locally so the next cold-start is instant.
      await _prefs.setBool(_keyUrgent, serverNewRequests);
      await _prefs.setBool(_keyMessages, serverMessages);
    } catch (e) {
      debugPrint('NotificationSettings: failed to load from server: $e');
    }
  }

  /// Persists the given [columns] map to the user's profile row.
  Future<void> _persistToServer(Map<String, dynamic> columns) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('profiles').update(columns).eq('id', userId);
    } catch (e) {
      debugPrint('NotificationSettings: failed to persist to server: $e');
    }
  }

  Future<void> setPushEnabled(bool value) async {
    state = state.copyWith(pushEnabled: value);
    await _prefs.setBool(_keyPush, value);
    // pushEnabled is local-only — the FCM bootstrap watches it and
    // registers/unregisters the device token accordingly.
  }

  Future<void> setUrgentRequests(bool value) async {
    state = state.copyWith(urgentRequests: value);
    await _prefs.setBool(_keyUrgent, value);
    await _persistToServer({'notify_new_requests': value});
  }

  Future<void> setNewMessages(bool value) async {
    state = state.copyWith(newMessages: value);
    await _prefs.setBool(_keyMessages, value);
    await _persistToServer({'notify_messages': value});
  }

  Future<void> setVerificationUpdates(bool value) async {
    state = state.copyWith(verificationUpdates: value);
    await _persistToServer({'notify_verification_updates': value});
  }

  Future<void> setTopDonorUpdates(bool value) async {
    state = state.copyWith(topDonorUpdates: value);
    await _persistToServer({'notify_top_donor_updates': value});
  }
}

/// Shared instance injected via an override in `main()` after
/// `SharedPreferences.getInstance()` completes.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  );
});

final notificationSettingsProvider = StateNotifierProvider<
    NotificationSettingsNotifier, NotificationSettings>((ref) {
  return NotificationSettingsNotifier(
    ref.watch(sharedPreferencesProvider),
    ref.watch(supabaseClientProvider),
  );
});
