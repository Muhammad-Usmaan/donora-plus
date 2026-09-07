import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../services/supabase/supabase_client_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// Notification types supported by the app.
enum NotificationType {
  urgentRequest,
  newRequest,
  requestAccepted,
  requestFulfilled,
  requestExpired,
  verificationApproved,
  newMessage,
  topDonor,
  achievementUnlocked,
  generic;

  factory NotificationType.fromString(String? value) {
    switch (value) {
      case 'urgent_request':
        return NotificationType.urgentRequest;
      case 'new_request':
        return NotificationType.newRequest;
      case 'request_accepted':
        return NotificationType.requestAccepted;
      case 'request_fulfilled':
        return NotificationType.requestFulfilled;
      case 'request_expired':
        return NotificationType.requestExpired;
      case 'verification_approved':
        return NotificationType.verificationApproved;
      case 'new_message':
        return NotificationType.newMessage;
      case 'top_donor':
        return NotificationType.topDonor;
      case 'achievement_unlocked':
        return NotificationType.achievementUnlocked;
      default:
        return NotificationType.generic;
    }
  }
}

/// A single in-app notification.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.deepLinkId,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Optional ID for deep-linking (e.g. request_id, conversation_id).
  final String? deepLinkId;

  factory AppNotification.fromMap(Map<String, dynamic> map) =>
      AppNotification(
        id: map['id'] as String? ?? '',
        type:
            NotificationType.fromString(map['type'] as String?),
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
                DateTime.now(),
        isRead: map['is_read'] as bool? ?? false,
        deepLinkId: map['deep_link_id'] as String?,
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Fetches all notifications for the current user, newest first.
final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);

  // Realtime: re-fetch notifications whenever a new one is inserted
  // (server-side inserts via Edge Functions). Keeps the notification
  // red dot and list up to date without polling.
  final channel = client
      .channel('notifications_realtime')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        callback: (_) {
          ref.invalidateSelf();
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });

  try {
    final data = await client
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);

    return (data as List)
        .map((row) =>
            AppNotification.fromMap(row as Map<String, dynamic>))
        .toList();
  } on PostgrestException catch (e) {
    // Table doesn't exist yet — graceful fallback.
    if (e.code == '42P01' || e.message.contains('does not exist')) {
      return <AppNotification>[];
    }
    rethrow;
  }
});

/// Total unread notifications for the current user.
// Derived from notificationsProvider so it stays in sync automatically
// when the list is refreshed or invalidated.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.whenOrNull(
        data: (list) => list.where((n) => !n.isRead).length,
      ) ??
      0;
});

/// Marks a single notification as read.
final markNotificationReadProvider =
    Provider<MarkNotificationReadAction>((ref) {
  return MarkNotificationReadAction(ref);
});

class MarkNotificationReadAction {
  MarkNotificationReadAction(this._ref);
  final Ref _ref;

  Future<void> call(String notificationId) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.from('notifications').update({
        'is_read': true,
      }).eq('id', notificationId);
      // Invalidate so the list refreshes.
      _ref.invalidate(notificationsProvider);
    } catch (_) {
      // Silently fail — non-critical.
    }
  }
}

/// Marks all notifications as read.
final markAllNotificationsReadProvider =
    Provider<MarkAllNotificationsReadAction>((ref) {
  return MarkAllNotificationsReadAction(ref);
});

class MarkAllNotificationsReadAction {
  MarkAllNotificationsReadAction(this._ref);
  final Ref _ref;

  Future<void> call() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final client = _ref.read(supabaseClientProvider);
      await client.from('notifications').update({
        'is_read': true,
      }).eq('user_id', user.id).eq('is_read', false);
      _ref.invalidate(notificationsProvider);
    } catch (_) {
      // Silently fail — non-critical.
    }
  }
}
