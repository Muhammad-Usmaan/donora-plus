import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles Firebase Cloud Messaging: permission requests, token management,
/// and saving the device token to the user's Supabase profile.
///
/// Every method degrades gracefully when Firebase is unavailable (e.g. when
/// google-services.json / GoogleService-Info.plist is missing) — the rest of
/// the app keeps working, just without push notifications.
class FcmService {
  FcmService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// The messaging entry point, or null when Firebase never initialized.
  FirebaseMessaging? get _messaging =>
      Firebase.apps.isEmpty ? null : FirebaseMessaging.instance;

  /// Whether Firebase was initialized and FCM is usable.
  static bool get isAvailable => Firebase.apps.isNotEmpty;

  bool _initialized = false;

  /// Background / terminated message handler.
  ///
  /// MUST be a static top-level-entry function so the engine can re-register
  /// it when the app process is relaunched from a notification. Notification
  /// messages are displayed by the OS itself; data-only messages would be
  /// processed here.
  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {
    // Intentionally a no-op for now.
  }

  /// Full setup for a signed-in user: background handler registration,
  /// permission prompt, token sync, and token-refresh listener.
  Future<void> initialize() async {
    final messaging = _messaging;
    if (messaging == null || _initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(backgroundHandler);

    await requestPermission();
    await saveTokenToProfile();

    // Keep the stored token fresh across token rotations.
    messaging.onTokenRefresh.listen((_) {
      saveTokenToProfile();
    });
  }

  /// Requests notification permission (Android 13+ / iOS).
  Future<void> requestPermission() async {
    final messaging = _messaging;
    if (messaging == null) return;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Returns the current FCM token, or null when FCM is unavailable.
  Future<String?> getToken() async {
    final messaging = _messaging;
    if (messaging == null) return null;
    return messaging.getToken();
  }

  /// Saves the FCM token to the authenticated user's profile row
  /// so the backend can send targeted push notifications.
  Future<void> saveTokenToProfile() async {
    final token = await getToken();
    final userId = _supabase.auth.currentUser?.id;
    if (token == null || userId == null) return;
    await _supabase
        .from('profiles')
        .update({'fcm_token': token})
        .eq('id', userId);
  }

  /// Removes the device token so the backend stops targeting this device
  /// (e.g. on sign-out or when the user disables push notifications).
  ///
  /// [userId] lets callers clean up during sign-out, after the Supabase
  /// session is already gone.
  Future<void> clearToken({String? userId}) async {
    final id = userId ?? _supabase.auth.currentUser?.id;
    final messaging = _messaging;

    if (id != null) {
      try {
        await _supabase
            .from('profiles')
            .update({'fcm_token': null})
            .eq('id', id);
      } catch (_) {
        // Best-effort cleanup — non-critical.
      }
    }
    if (messaging != null) {
      try {
        await messaging.deleteToken();
      } catch (_) {
        // Token may already be invalid — ignore.
      }
    }
  }

  /// Message that launched the app from a terminated state, if any.
  Future<RemoteMessage?> getInitialMessage() async {
    final messaging = _messaging;
    if (messaging == null) return null;
    return messaging.getInitialMessage();
  }

  /// Stream of token refresh events — [saveTokenToProfile] is called
  /// automatically when fired.
  Stream<String> get onTokenRefresh =>
      _messaging?.onTokenRefresh ?? const Stream<String>.empty();

  /// Listens for messages delivered while the app is in the foreground.
  ///
  /// Returns the subscription so callers can cancel it when they rebuild.
  StreamSubscription<RemoteMessage>? onForegroundMessage(
    void Function(RemoteMessage) handler,
  ) {
    if (!isAvailable) return null;
    return FirebaseMessaging.onMessage.listen(handler);
  }

  /// Stream of notification taps that resumed a backgrounded app.
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
}
