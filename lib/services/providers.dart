import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chatbot/chatbot_service.dart';
import 'chatbot/qwen_chatbot_service.dart';
import 'notifications/fcm_service.dart';
import 'notifications/push_notification_service.dart';
import 'location/location_service.dart';
import 'supabase/supabase_client_provider.dart';

/// Provides the abstract ChatbotService (Qwen implementation).
final chatbotServiceProvider = Provider<ChatbotService>((ref) {
  return QwenChatbotService(ref.watch(supabaseClientProvider));
});

/// Provides the FCM push-notification service.
final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService();
});

/// Provides the geolocation / city-resolution service.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Provides the push notification trigger service.
/// Used by providers to send FCM push notifications for trigger events
/// (new message, request response, etc.).
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.watch(supabaseClientProvider));
});
