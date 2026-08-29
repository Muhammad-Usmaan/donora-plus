import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../providers/notification_providers.dart';

/// Notifications list — grouped by "Today" / "Earlier".
///
/// Each notification has a type-specific icon/color, unread dot,
/// and deep-links to the relevant screen on tap.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text('Notifications'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          notificationsAsync.whenOrNull(
                data: (list) {
                  final hasUnread = list.any((n) => !n.isRead);
                  if (!hasUnread) return null;
                  return IconButton(
                    icon: const Icon(Icons.done_all, size: 20),
                    tooltip: 'Mark all as read',
                    onPressed: () {
                      ref.read(markAllNotificationsReadProvider)();
                    },
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const _EmptyNotificationsState();
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
            },
            child: _GroupedNotificationList(
              notifications: notifications,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 40, color: colors.textMedium),
                const SizedBox(height: 12),
                Text(
                  'Could not load notifications',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textHigh,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Grouped list ─────────────────────────────────────────────────────────────

class _GroupedNotificationList extends StatelessWidget {
  const _GroupedNotificationList({required this.notifications});

  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    // Split into "Today" and "Earlier".
    final today = <AppNotification>[];
    final earlier = <AppNotification>[];

    for (final n in notifications) {
      if (n.createdAt.isToday) {
        today.add(n);
      } else {
        earlier.add(n);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (today.isNotEmpty) ...[
          const _SectionHeader(label: 'Today'),
          const SizedBox(height: 8),
          ...today.map((n) => _NotificationCard(notification: n)),
        ],
        if (earlier.isNotEmpty) ...[
          if (today.isNotEmpty) const SizedBox(height: 20),
          const _SectionHeader(label: 'Earlier'),
          const SizedBox(height: 8),
          ...earlier.map((n) => _NotificationCard(notification: n)),
        ],
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: colors.textMedium,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── Notification card ─────────────────────────────────────────────────────────

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () {
          // Mark as read on tap.
          if (!notification.isRead) {
            ref
                .read(markNotificationReadProvider)
                (notification.id);
          }
          // Deep-link to the relevant screen.
          _navigateToTarget(context);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type icon
            _NotificationIcon(type: notification.type),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textHigh,
                          ),
                        ),
                      ),
                      Text(
                        Formatters.timeAgo(notification.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textMedium,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Unread dot
            if (!notification.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToTarget(BuildContext context) {
    final linkId = notification.deepLinkId;

    switch (notification.type) {
      case NotificationType.urgentRequest:
        if (linkId != null) {
          context.pushNamed(
            RouteNames.requestDetail,
            pathParameters: {'id': linkId},
          );
        }
        break;
      case NotificationType.newMessage:
        if (linkId != null) {
          context.pushNamed(
            RouteNames.conversation,
            pathParameters: {'id': linkId},
          );
        } else {
          context.pushNamed(RouteNames.chat);
        }
        break;
      case NotificationType.verificationApproved:
        context.pushNamed(RouteNames.profile);
        break;
      case NotificationType.topDonor:
        context.pushNamed(RouteNames.profile);
        break;
      case NotificationType.generic:
        // No navigation for generic notifications.
        break;
    }
  }
}

// ── Notification icon ─────────────────────────────────────────────────────────

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.type});

  final NotificationType type;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final Color bgColor;
    final Color iconColor;
    final IconData icon;

    switch (type) {
      case NotificationType.urgentRequest:
        bgColor = colors.urgentContainer;
        iconColor = colors.urgent;
        icon = Icons.bloodtype;
        break;
      case NotificationType.verificationApproved:
        bgColor = const Color(0xFFE8F5E9);
        iconColor = colors.success;
        icon = Icons.check_circle_outline;
        break;
      case NotificationType.newMessage:
        bgColor = colors.secondaryContainer;
        iconColor = colors.secondary;
        icon = Icons.chat_bubble_outline;
        break;
      case NotificationType.topDonor:
        bgColor = const Color(0xFFFFF8E1);
        iconColor = const Color(0xFFF9A825);
        icon = Icons.emoji_events;
        break;
      case NotificationType.generic:
        bgColor = colors.primaryContainer;
        iconColor = colors.primary;
        icon = Icons.notifications_outlined;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none,
                size: 40,
                color: colors.secondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "You're all caught up",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textHigh,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No new notifications right now.\nWe\'ll let you know when something comes up.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colors.textMedium,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
