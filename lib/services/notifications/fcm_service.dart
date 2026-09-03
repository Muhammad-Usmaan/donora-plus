import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles Firebase Cloud Messaging: permission requests, token management,
/// and saving the device token to the user's `device_tokens` table in
/// Supabase so the backend can send targeted push notifications.
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
    // Intentionally a no-op — notification messages are displayed by the OS.
  }

  /// Full setup for a signed-in user: background handler registration,
  /// permission prompt, token sync, and token-refresh listener.
  Future<void> initialize() async {
    final messaging = _messaging;
    if (messaging == null || _initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(backgroundHandler);

    await requestPermission();
    await saveToken();

    // Keep the stored token fresh across token rotations.
    messaging.onTokenRefresh.listen((_) {
      saveToken();
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

  /// Saves the FCM token to the `device_tokens` table via the
  /// `upsert_device_token` RPC. Supports multiple devices per user —
  /// the same token re-upserted just refreshes `updated_at`.
  ///
  /// Retries up to 3 times with exponential backoff on transient network
  /// errors (e.g. TLS handshake failures) so the device doesn't miss push
  /// notifications until the next app launch.
  Future<void> saveToken() async {
    final token = await getToken();
    final userId = _supabase.auth.currentUser?.id;
    if (token == null || userId == null) return;

    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _supabase.rpc(
          'upsert_device_token',
          params: {
            'p_token': token,
            'p_platform': _currentPlatform,
          },
        );
        return; // success
      } catch (e) {
        if (attempt == maxAttempts) {
          debugPrint('FCM: failed to save token after $maxAttempts attempts: $e');
          return;
        }
        // Exponential backoff: 1s, 2s, 4s …
        await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    }
  }

  /// Removes the device token so the backend stops targeting this device
  /// (e.g. on sign-out or when the user disables push notifications).
  ///
  /// [userId] lets callers clean up during sign-out, after the Supabase
  /// session is already gone.
  Future<void> clearToken({String? userId}) async {
    final messaging = _messaging;
    String? token;

    try {
      token = await messaging?.getToken();
    } catch (_) {
      // Token may already be invalid.
    }

    final id = userId ?? _supabase.auth.currentUser?.id;

    // Remove from device_tokens via RPC (uses auth.uid() internally).
    if (id != null && token != null) {
      try {
        await _supabase.rpc(
          'delete_device_token',
          params: {'p_token': token},
        );
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

  /// Stream of token refresh events — [saveToken] is called
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

  /// Detects the current platform for the `device_tokens.platform` column.
  static String? get _currentPlatform {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {
      // Platform not available (e.g. in tests).
    }
    return null;
  }
}
