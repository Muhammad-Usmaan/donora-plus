import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../home/providers/home_providers.dart';
import '../widgets/profile_dialogs.dart';

/// Account settings sub-page: edit profile, change password, phone, email.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text('Account'),
        centerTitle: false,
      ),
      body: profileAsync.when(
        data: (profile) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.person_outline,
                    label: 'Edit Profile',
                    onTap: () => showEditNameDialog(
                      context,
                      ref: ref,
                      currentName: profile.name,
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingsRow(
                    icon: Icons.lock_outline,
                    label: 'Change Password',
                    onTap: () => showChangePasswordDialog(context, ref: ref),
                  ),
                  const Divider(height: 1),
                  _SettingsRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    subtitle: _phoneSubtitle(profile),
                    onTap: () => showEditPhoneDialog(
                      context,
                      ref: ref,
                      currentPhone: profile.phone,
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingsRow(
                    icon: Icons.alternate_email,
                    label: 'Email',
                    subtitle: profile.email,
                    showChevron: false,
                    trailing: Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: context.colors.textMedium,
                    ),
                    onTap: () => _showEmailInfoDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Could not load data',
              style: TextStyle(color: colors.textMedium),
            ),
          ),
        ),
      ),
    );
  }

  String? _phoneSubtitle(UserProfile p) {
    if (p.phone == null || p.phone!.isEmpty) {
      return 'Not set \u2014 tap to add';
    }
    return p.phone;
  }

  void _showEmailInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Email Address',
        message: 'For security reasons, your email address can\'t be '
            'changed. It is used to sign in to Donora+.',
        icon: Icons.alternate_email,
        iconColor: context.colors.secondary,
        actions: [
          DialogActionButton(
            label: 'Got It',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}

// ── Settings row (local copy for this sub-page) ──────────────────────────────

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.textMedium),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.textHigh,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            if (showChevron)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colors.textMedium,
              ),
          ],
        ),
      ),
    );
  }
}
