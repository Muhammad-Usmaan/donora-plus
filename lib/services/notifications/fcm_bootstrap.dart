import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart'
    hide NotificationSettings;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../features/notifications/providers/notification_settings_provider.dart';
import '../providers.dart';
import 'fcm_service.dart';

/// Global messenger key so services can show foreground notification banners
/// above any route. Attached to the root [MaterialApp].
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Boots the FCM lifecycle for the signed-in user:
/// - registers the background handler and syncs the device token,
/// - shows an in-app banner for foreground messages,
/// - deep-links to the target screen when a notification is tapped,
/// - keeps the push master toggle ([NotificationSettings.pushEnabled]) in
///   sync with the token stored on the profile row.
///
/// Watch this from the root widget so it stays alive for the whole session.
final fcmBootstrapProvider = Provider<void>((ref) {
  final fcm = ref.watch(fcmServiceProvider);
  final user = ref.watch(currentUserProvider);
  final settings = ref.watch(notificationSettingsProvider);

  if (!FcmService.isAvailable || user == null) return;

  // Foreground messages → in-app banner. Attached once per signed-in session.
  StreamSubscription<RemoteMessage>? foregroundSub;
  foregroundSub = fcm.onForegroundMessage((message) {
    _showForegroundBanner(ref, message, settings);
  });

  // Notification tap that resumed a backgrounded app → deep link.
  StreamSubscription<RemoteMessage>? openedSub;
  openedSub = fcm.onMessageOpenedApp.listen((message) {
    _deepLink(ref, message);
  });

  // Cold start from a terminated state → deep link once the shell is up.
  unawaited(
    fcm.getInitialMessage().then((message) {
      if (message != null) _deepLink(ref, message);
    }),
  );

  // Honor the push master toggle: register or unregister the device token.
  unawaited(
    settings.pushEnabled ? fcm.initialize() : fcm.clearToken(),
  );

  ref.onDispose(() {
    foregroundSub?.cancel();
    openedSub?.cancel();
  });
});

/// Shows a floating banner with the notification title/body and a View action.
void _showForegroundBanner(
  Ref ref,
  RemoteMessage message,
  NotificationSettings settings,
) {
  final notification = message.notification;
  final title = notification?.title ?? message.data['title'] as String?;
  final body = notification?.body ?? message.data['body'] as String?;
  if (title == null && body == null) return;

  // Respect per-type preferences — silent for disabled categories.
  if (!_categoryEnabled(message, settings)) return;

  // The banner renders above the widget tree via the root messenger key,
  // so read tokens from the static light palette (single-theme app).
  const colors = AppColors.light;

  rootScaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.card,
      duration: const Duration(seconds: 5),
      content: Row(
        children: [
          Icon(Icons.notifications_active, size: 22, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textHigh,
                    ),
                  ),
                if (body != null)
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: colors.textMedium),
                  ),
              ],
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: 'View',
        textColor: colors.primary,
        onPressed: () => _deepLink(ref, message),
      ),
    ),
  );
}

/// Whether the message's category is enabled in the user's preferences.
bool _categoryEnabled(RemoteMessage message, NotificationSettings settings) {
  final type = message.data['type'] as String?;
  switch (type) {
    case 'urgent_request':
    case 'new_request':
      return settings.urgentRequests;
    case 'new_message':
      return settings.newMessages;
    case 'request_accepted':
    case 'request_fulfilled':
    case 'request_expired':
      return settings.verificationUpdates; // request-updates category
    case 'verification_approved':
      return settings.verificationUpdates;
    case 'top_donor':
      return settings.topDonorUpdates;
    case 'achievement_unlocked':
      return true; // achievements category (no dedicated toggle in settings yet)
    default:
      return true;
  }
}

/// Navigates to the screen targeted by a notification's data payload.
///
/// Uses the same `type` + `deep_link_id` convention as the in-app
/// notifications table.
void _deepLink(Ref ref, RemoteMessage message) {
  final user = ref.read(currentUserProvider);
  if (user == null) return;

  final router = ref.read(routerProvider);
  final type = message.data['type'] as String?;
  final linkId = message.data['deep_link_id'] as String?;

  switch (type) {
    case 'urgent_request':
    case 'new_request':
      if (linkId != null && linkId.isNotEmpty) {
        router.pushNamed(
          RouteNames.requestDetail,
          pathParameters: {'id': linkId},
        );
      } else {
        router.pushNamed(RouteNames.notifications);
      }
    case 'request_accepted':
    case 'request_fulfilled':
    case 'request_expired':
      if (linkId != null && linkId.isNotEmpty) {
        router.pushNamed(
          RouteNames.requestDetail,
          pathParameters: {'id': linkId},
        );
      } else {
        router.pushNamed(RouteNames.myRequests);
      }
    case 'new_message':
      if (linkId != null && linkId.isNotEmpty) {
        router.pushNamed(
          RouteNames.conversation,
          pathParameters: {'id': linkId},
        );
      } else {
        router.pushNamed(RouteNames.chat);
      }
    case 'verification_approved':
    case 'top_donor':
      router.pushNamed(RouteNames.profile);
    case 'achievement_unlocked':
      if (linkId != null && linkId.isNotEmpty) {
        router.pushNamed(
          RouteNames.achievementCelebration,
          pathParameters: {'id': linkId},
        );
      } else {
        router.pushNamed(RouteNames.notifications);
      }
    default:
      router.pushNamed(RouteNames.notifications);
  }
}
