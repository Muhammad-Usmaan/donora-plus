import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chatbot/chatbot_service.dart';
import 'chatbot/qwen_chatbot_service.dart';
import 'notifications/fcm_service.dart';
import 'location/location_service.dart';

/// Provides the abstract ChatbotService (Qwen implementation).
final chatbotServiceProvider = Provider<ChatbotService>((ref) {
  return QwenChatbotService();
});

/// Provides the FCM push-notification service.
final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService();
});

/// Provides the geolocation / city-resolution service.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
