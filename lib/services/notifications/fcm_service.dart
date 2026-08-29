import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles Firebase Cloud Messaging: permission requests, token management,
/// and saving the device token to the user's Supabase profile.
class FcmService {
  FcmService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Request notification permissions (mainly needed on iOS).
  Future<NotificationSettings> requestPermission() async {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Returns the current FCM token for push notifications.
  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  /// Saves the FCM token to the authenticated user's profile row
  /// so the backend can send targeted push notifications.
  Future<void> saveTokenToProfile() async {
    final token = await getToken();
    final userId = _supabase.auth.currentUser?.id;
    if (token != null && userId != null) {
      await _supabase
          .from('profiles')
          .update({'fcm_token': token}).eq('id', userId);
    }
  }

  /// Stream of token refresh events — call [saveTokenToProfile] when fired.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Listen for foreground messages (when app is open).
  void onForegroundMessage(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessage.listen(handler);
  }
}
