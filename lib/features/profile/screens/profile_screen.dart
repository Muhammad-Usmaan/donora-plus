import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../home/providers/home_providers.dart';
import '../../chat/providers/chat_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_dialogs.dart';

/// Profile & Settings screen for Donora+.
///
/// Lightweight landing page with navigation entries to sub-pages.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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
        title: const Text('Profile & Settings'),
        centerTitle: false,
      ),
      body: profileAsync.when(
        data: (profile) => _ProfileBody(profile: profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: colors.textMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Could not load profile',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textHigh,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textMedium,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Profile body ─────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final UserProfile profile;

  bool get _isDonor =>
      profile.activeRole == 'donor' ||
      profile.donorClassification.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        // Header (with verification + top-donor badges)
        _RedesignedHeader(profile: profile),
        const SizedBox(height: 16),

        // Role toggle (promoted from Preferences)
        _RoleSwitcherRow(currentRole: profile.activeRole),
        const SizedBox(height: 24),

        // ── Navigation entries ──────────────────────────────────────
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.bar_chart,
                label: 'Donation Overview',
                onTap: () => context.pushNamed(
                    RouteNames.profileDonationOverview),
              ),
              if (_isDonor) ...[
                const Divider(height: 1),
                _SettingsRow(
                  icon: Icons.settings_outlined,
                  label: 'Donor Settings',
                  onTap: () => context.pushNamed(
                      RouteNames.profileDonorSettings),
                ),
                const Divider(height: 1),
                _SettingsRow(
                  icon: Icons.emoji_events_outlined,
                  label: 'Achievements',
                  onTap: () => context.pushNamed(
                      RouteNames.profileAchievements),
                ),
              ],
              const Divider(height: 1),
              _SettingsRow(
                icon: Icons.account_circle_outlined,
                label: 'Account',
                onTap: () => context.pushNamed(
                    RouteNames.profileAccount),
              ),
              const Divider(height: 1),
              _SettingsRow(
                icon: Icons.tune,
                label: 'Preferences',
                onTap: () => context.pushNamed(
                    RouteNames.profilePreferences),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Emergency
        const _EmergencyCard(),
        const SizedBox(height: 16),

        // Request History (seeker only)
        if (profile.activeRole == 'seeker') ...[
          AppCard(
            padding: EdgeInsets.zero,
            child: _SettingsRow(
              icon: PhosphorIconsRegular.clockCounterClockwise,
              label: 'Request History',
              onTap: () => context.pushNamed(RouteNames.myRequests),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Support ─────────────────────────────────────────────────
        const _SectionTitle(title: 'Support'),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.help_outline,
                label: 'Help & FAQ',
                onTap: () => context.pushNamed(RouteNames.helpFaq),
              ),
              const Divider(height: 1),
              _SettingsRow(
                icon: Icons.support_agent,
                label: 'Contact Support',
                onTap: () => showContactSupportDialog(context),
              ),
              const Divider(height: 1),
              _SettingsRow(
                icon: Icons.info_outline,
                label: 'About Donora+',
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Account Actions ─────────────────────────────────────────
        const _SectionTitle(title: 'Account Actions'),
        const SizedBox(height: 8),
        const AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _LogoutRow(),
              Divider(height: 1),
              _DeleteAccountRow(),
            ],
          ),
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) async {
    final uri = Uri.parse('https://donoraplus.vercel.app/');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          context.showSnackBar(
            'Could not open website. Please try again.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar(
          'Could not open website. Please try again.',
          isError: true,
        );
      }
    }
  }
}

// ── Section title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: colors.textMedium,
        letterSpacing: 0.2,
      ),
    );
  }
}

// ── Settings row ─────────────────────────────────────────────────────────────

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

  /// Whether to show the navigation chevron (hide for info-only rows).
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

// ── Role switcher row ────────────────────────────────────────────────────────

class _RoleSwitcherRow extends ConsumerStatefulWidget {
  const _RoleSwitcherRow({required this.currentRole});

  final String currentRole;

  @override
  ConsumerState<_RoleSwitcherRow> createState() => _RoleSwitcherRowState();
}

class _RoleSwitcherRowState extends ConsumerState<_RoleSwitcherRow> {
  int _computeAge(DateTime date) {
    final now = DateTime.now();
    int age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age;
  }

  void _onDonorTap() {
    final profileAsync = ref.read(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final dob = profile?.dateOfBirth;

    if (dob == null) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Date of Birth Required',
          message:
              'To switch to a donor account, we need your date of birth to verify you are 18 or older. Please add it to your profile first.',
          icon: Icons.cake_outlined,
          iconColor: context.colors.secondary,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later'),
            ),
            DialogActionButton(
              label: 'Add Date of Birth',
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickAndSetDob();
              },
            ),
          ],
        ),
      );
      return;
    }

    if (_computeAge(dob) < 18) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: 'Age Restriction',
          message: 'You must be 18 or older to register as a donor.',
          icon: Icons.info_outline,
          iconColor: context.colors.urgent,
          actions: [
            DialogActionButton(
              label: 'OK',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
      return;
    }

    ref.read(switchRoleActionProvider)('donor');
  }

  Future<void> _pickAndSetDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null || !mounted) return;

    final formatted =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(updateProfileFieldProvider)({
        'date_of_birth': formatted,
      });
      if (!mounted) return;
      ref.read(switchRoleActionProvider)('donor');
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to save date of birth: $e',
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeRole = ref.watch(activeRoleProvider);
    final isSeeker = activeRole == 'seeker';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleOption(
              label: 'Seeker',
              selected: isSeeker,
              onTap: () {
                ref.read(switchRoleActionProvider)('seeker');
              },
            ),
          ),
          Expanded(
            child: _ToggleOption(
              label: 'Donor',
              selected: !isSeeker,
              onTap: _onDonorTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.textMedium,
          ),
        ),
      ),
    );
  }
}

// ── Logout row ───────────────────────────────────────────────────────────────

class _LogoutRow extends ConsumerStatefulWidget {
  const _LogoutRow();

  @override
  ConsumerState<_LogoutRow> createState() => _LogoutRowState();
}

class _LogoutRowState extends ConsumerState<_LogoutRow> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;

    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Log out?',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log Out',
      icon: Icons.logout,
    );
    if (!confirmed) return;

    setState(() => _isLoggingOut = true);

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AppDialog(
          title: 'Logging out',
          message: 'Please wait\u2026',
          icon: Icons.logout,
          iconColor: context.colors.textHigh,
          actions: const [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );

    try {
      await ref.read(logoutActionProvider)();
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        setState(() => _isLoggingOut = false);
        context.showSnackBar(
          'Failed to log out. Please try again.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: _isLoggingOut ? null : _handleLogout,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.logout, size: 22, color: colors.textHigh),
            const SizedBox(width: 14),
            Text(
              'Log Out',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Delete account row ───────────────────────────────────────────────────────

class _DeleteAccountRow extends ConsumerWidget {
  const _DeleteAccountRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return InkWell(
      onTap: () => _showDeleteDialog(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 22, color: colors.urgent),
            const SizedBox(width: 14),
            Text(
              'Delete Account',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.urgent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showConfirmDialog(
      context: context,
      title: 'Delete your account?',
      message:
          'This action is permanent and cannot be undone. All your data, '
          'including requests and messages, will be deleted.',
      confirmLabel: 'Delete Account',
      icon: Icons.delete_outline,
      destructive: true,
    ).then((confirmed) async {
      if (!confirmed) return;

      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AppDialog(
            title: 'Deleting your account',
            message: 'Please wait\u2026',
            icon: Icons.delete_outline,
            iconColor: context.colors.urgent,
            actions: const [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      );

      final success =
          await ref.read(deleteAccountActionProvider)();

      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted && !success) {
        context.showSnackBar(
          'Failed to delete account. Please try again.',
          isError: true,
        );
      }
    });
  }
}

// ── Redesigned header ────────────────────────────────────────────────────────

class _RedesignedHeader extends ConsumerStatefulWidget {
  const _RedesignedHeader({required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<_RedesignedHeader> createState() =>
      _RedesignedHeaderState();
}

class _RedesignedHeaderState extends ConsumerState<_RedesignedHeader> {
  bool _isUploading = false;

  Future<void> _pickAndUpload(ImageSource source) async {
    setState(() => _isUploading = true);
    try {
      await ref.read(uploadProfilePhotoAction)(source);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final colors = context.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  'Change Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textHigh,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.photo_library,
                        size: 20, color: colors.primary),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickAndUpload(ImageSource.gallery);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.camera_alt,
                        size: 20, color: colors.secondary),
                  ),
                  title: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickAndUpload(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = widget.profile;

    return Row(
      children: [
        // Avatar with verification + top-donor badge overlays
        GestureDetector(
          onTap: _isUploading ? null : _showPhotoSourceSheet,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: _isUploading ? 0.4 : 1.0,
                child: _CompactAvatar(
                  name: profile.name,
                  photoUrl: profile.profilePhotoUrl,
                ),
              ),
              if (_isUploading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              // Verification badge — bottom-right corner
              if (profile.isVerified && !_isUploading)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: colors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.card, width: 2),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              // Top donor badge — top-right corner
              if (profile.isTopDonor && !_isUploading)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: colors.warning,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.card, width: 2),
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Greeting + join date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey ${profile.name.split(' ').first}!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textHigh,
                ),
              ),
              if (profile.createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    Formatters.dateShort(profile.createdAt!),
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textMedium,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Message icon
        GestureDetector(
          onTap: () => context.pushNamed(RouteNames.chat),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: PhosphorIcon(
                    PhosphorIconsRegular.chatCircle,
                    size: 20,
                    color: colors.textHigh,
                  ),
                ),
                // Red dot — only when there are unread messages.
                if (ref.watch(unreadMessageCountProvider) > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.urgent,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.card, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Notification bell
        GestureDetector(
          onTap: () => context.pushNamed(RouteNames.notifications),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: colors.textHigh,
                  ),
                ),
                // Red dot — only when there are unread notifications.
                if (ref.watch(unreadNotificationCountProvider) > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.urgent,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.card, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Compact avatar ───────────────────────────────────────────────────────────

class _CompactAvatar extends StatelessWidget {
  const _CompactAvatar({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 32,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: colors.primaryContainer,
      );
    }
    return CircleAvatar(
      radius: 32,
      backgroundColor: colors.primaryContainer,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: colors.primary,
        ),
      ),
    );
  }
}

// ── Emergency Card ───────────────────────────────────────────────────────────

/// External URL for emergency/precautions info.
/// Temporary placeholder until a dedicated blog/precautions page exists
/// on the marketing site — one-line change when the real URL is ready.
const String emergencyInfoUrl = 'https://donoraplus.vercel.app/faq';

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard();

  Future<void> _openEmergencyInfo(BuildContext context) async {
    final uri = Uri.parse(emergencyInfoUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          context.showSnackBar('Could not open $emergencyInfoUrl');
        }
      }
    } catch (_) {
      if (context.mounted) {
        context.showSnackBar('Could not open $emergencyInfoUrl');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      onTap: () => _openEmergencyInfo(context),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.urgentContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.emergency,
              size: 22,
              color: colors.urgent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textHigh,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stay Safe After Giving Blood.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: colors.textMedium,
          ),
        ],
      ),
    );
  }
}
