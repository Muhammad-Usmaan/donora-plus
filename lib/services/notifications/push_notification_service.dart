import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client-side service for triggering push notifications.
///
/// The flow is:
///   1. Call `prepare_notification` RPC → checks preferences, inserts the
///      in-app notification row, and returns the recipient's device tokens.
///   2. If tokens are returned, invoke the `send-push-notification` edge
///      function to deliver them via FCM.
///
/// This is intentionally fire-and-forget — callers should not await or
/// block UI on push delivery. Failures are logged but never thrown.
class PushNotificationService {
  const PushNotificationService(this._supabase);

  final SupabaseClient _supabase;

  /// Sends a push notification to a single [recipientId].
  ///
  /// [type] maps to both the in-app notification type and the FCM data
  /// payload (used by the foreground banner and deep-link router).
  ///
  /// [deepLinkId] is the ID of the target entity (request ID, conversation
  /// ID, etc.) used by the deep-link router when the notification is tapped.
  Future<void> send({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    String? deepLinkId,
  }) async {
    try {
      // 1. Prepare: check preferences + insert in-app notification + get tokens.
      final result = await _supabase.rpc(
        'prepare_notification',
        params: {
          'p_recipient_id': recipientId,
          'p_type': type,
          'p_title': title,
          'p_body': body,
          'p_deep_link_id': deepLinkId,
        },
      );

      final map = result as Map<String, dynamic>? ?? {};
      if (map['sent'] != true) return; // preference disabled or error

      final tokens = (map['tokens'] as List?)?.cast<String>() ?? [];
      if (tokens.isEmpty) return; // no devices registered

      // 2. Invoke the edge function to deliver via FCM.
      final session = _supabase.auth.currentSession;
      if (session == null) return;

      await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'tokens': tokens,
          'type': type,
          'title': title,
          'body': body,
          'deep_link_id': deepLinkId ?? '',
        },
      );
    } catch (e) {
      // Non-critical — push delivery should never break the caller's flow.
      debugPrint('PushNotificationService.send failed: $e');
    }
  }

  /// Sends the same notification to multiple recipients (fan-out).
  ///
  /// Useful for broadcasting a new urgent request to all matching donors.
  Future<void> sendToMany({
    required List<String> recipientIds,
    required String type,
    required String title,
    required String body,
    String? deepLinkId,
  }) async {
    // Fire all sends concurrently — each one is independent.
    await Future.wait(
      recipientIds.map(
        (id) => send(
          recipientId: id,
          type: type,
          title: title,
          body: body,
          deepLinkId: deepLinkId,
        ),
      ),
    );
  }
}
