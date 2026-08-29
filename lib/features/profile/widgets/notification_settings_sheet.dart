import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../notifications/providers/notification_settings_provider.dart';
import '../../../services/notifications/fcm_service.dart';

/// Bottom sheet for the "Notifications" preference row.
///
/// Master push toggle plus per-category switches, persisted locally via
/// [notificationSettingsProvider]. When push is enabled the FCM token is
/// (re-)registered on the profile; when disabled it is removed so the
/// backend stops targeting the device.
void showNotificationSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _NotificationSettingsSheet(),
  );
}

class _NotificationSettingsSheet extends ConsumerWidget {
  const _NotificationSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textHigh,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose what Donora+ alerts you about.',
              style: TextStyle(fontSize: 13, color: colors.textMedium),
            ),
            const SizedBox(height: 20),

            // FCM availability notice
            if (!FcmService.isAvailable) ...[
              AppCard(
                borderColor: colors.warning.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_outlined,
                        size: 20, color: colors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Push notifications are unavailable on this build. '
                        'In-app alerts still work.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.textMedium,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Master push toggle
            AppCard(
              padding: EdgeInsets.zero,
              child: _SettingsToggleTile(
                icon: Icons.notifications_active_outlined,
                title: 'Push Notifications',
                subtitle: 'Receive alerts on this device',
                value: settings.pushEnabled,
                onChanged: notifier.setPushEnabled,
                accent: colors.primary,
              ),
            ),
            const SizedBox(height: 12),

            // Category toggles — dimmed when push is off
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: settings.pushEnabled ? 1 : 0.45,
              child: AbsorbPointer(
                absorbing: !settings.pushEnabled,
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingsToggleTile(
                        icon: Icons.emergency,
                        title: 'Urgent Requests',
                        subtitle: 'Nearby emergency blood needs',
                        value: settings.urgentRequests,
                        onChanged: notifier.setUrgentRequests,
                      ),
                      Divider(height: 1, color: colors.border),
                      _SettingsToggleTile(
                        icon: Icons.chat_bubble_outline,
                        title: 'New Messages',
                        subtitle: 'Chat replies from seekers & donors',
                        value: settings.newMessages,
                        onChanged: notifier.setNewMessages,
                      ),
                      Divider(height: 1, color: colors.border),
                      _SettingsToggleTile(
                        icon: Icons.verified_user_outlined,
                        title: 'Verification Updates',
                        subtitle: 'Status of your donor verification',
                        value: settings.verificationUpdates,
                        onChanged: notifier.setVerificationUpdates,
                      ),
                      Divider(height: 1, color: colors.border),
                      _SettingsToggleTile(
                        icon: Icons.emoji_events_outlined,
                        title: 'Top Donor Awards',
                        subtitle: 'When you earn a Top Donor badge',
                        value: settings.topDonorUpdates,
                        onChanged: notifier.setTopDonorUpdates,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delivery also depends on your device notification settings.',
              style: TextStyle(fontSize: 11.5, color: colors.textMedium),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single labelled switch row.
class _SettingsToggleTile extends StatelessWidget {
  const _SettingsToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = accent ?? colors.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textHigh,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.5, color: colors.textMedium),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: colors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
