import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Persists [NotificationSettings] in SharedPreferences.
class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier(this._prefs)
      : super(const NotificationSettings()) {
    _load();
  }

  final SharedPreferences _prefs;

  static const _keyPush = 'notif.push_enabled';
  static const _keyUrgent = 'notif.urgent_requests';
  static const _keyMessages = 'notif.new_messages';
  static const _keyVerification = 'notif.verification_updates';
  static const _keyTopDonor = 'notif.top_donor_updates';

  void _load() {
    state = NotificationSettings(
      pushEnabled: _prefs.getBool(_keyPush) ?? true,
      urgentRequests: _prefs.getBool(_keyUrgent) ?? true,
      newMessages: _prefs.getBool(_keyMessages) ?? true,
      verificationUpdates: _prefs.getBool(_keyVerification) ?? true,
      topDonorUpdates: _prefs.getBool(_keyTopDonor) ?? true,
    );
  }

  Future<void> setPushEnabled(bool value) async {
    state = state.copyWith(pushEnabled: value);
    await _prefs.setBool(_keyPush, value);
  }

  Future<void> setUrgentRequests(bool value) async {
    state = state.copyWith(urgentRequests: value);
    await _prefs.setBool(_keyUrgent, value);
  }

  Future<void> setNewMessages(bool value) async {
    state = state.copyWith(newMessages: value);
    await _prefs.setBool(_keyMessages, value);
  }

  Future<void> setVerificationUpdates(bool value) async {
    state = state.copyWith(verificationUpdates: value);
    await _prefs.setBool(_keyVerification, value);
  }

  Future<void> setTopDonorUpdates(bool value) async {
    state = state.copyWith(topDonorUpdates: value);
    await _prefs.setBool(_keyTopDonor, value);
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
  return NotificationSettingsNotifier(ref.watch(sharedPreferencesProvider));
});
