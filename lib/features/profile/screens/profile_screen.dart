import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/donor_status_chip.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../home/providers/home_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/donation_history_sheet.dart';
import '../widgets/notification_settings_sheet.dart';
import '../widgets/profile_dialogs.dart';

/// Profile & Settings screen for Donora+.
///
/// Scrollable single-column layout with grouped AppCard sections,
/// 24px section spacing per the design system.
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

// ── Profile body ──────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final UserProfile profile;

  bool get _isDonor =>
      profile.activeRole == 'donor' ||
      profile.donorClassification.isNotEmpty;

  /// Subtitle for the Phone Number row.
  String? _phoneSubtitle(UserProfile p) {
    if (p.phone == null || p.phone!.isEmpty) {
      return 'Not set — tap to add';
    }
    return p.phone;
  }

  /// Email is fixed for security — explain instead of allowing edits.
  void _showEmailInfoDialog(BuildContext context) {
    showAppDialog(
      context: context,
      title: 'Email Address',
      message: 'For security reasons, your email address can\'t be '
          'changed. It is used to sign in to Donora+.',
      icon: Icons.alternate_email,
      iconColor: context.colors.secondary,
      actions: [
        DialogActionButton(
          label: 'Got It',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        // ── Header ─────────────────────────────────────────────
        _ProfileHeader(profile: profile),
        const SizedBox(height: 24),

        // ── Stats: Blood Type / Donated / Requested ──────────
        _StatsRow(profile: profile),
        const SizedBox(height: 24),

        // ── Account ────────────────────────────────────────────
        const _SectionTitle(title: 'Account'),
        const SizedBox(height: 8),
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
        const SizedBox(height: 24),

        // ── Donor Settings (conditional) ───────────────────────
        if (_isDonor) ...[
          const _SectionTitle(title: 'Donor Settings'),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.bloodtype,
                  label: 'Blood Type',
                  trailing: BloodTypeChip(
                    bloodType: profile.bloodGroup.isNotEmpty
                        ? profile.bloodGroup
                        : '—',
                  ),
                  onTap: () => _showBloodTypePicker(context, ref),
                ),
                const Divider(height: 1),
                _SettingsRow(
                  icon: Icons.history,
                  label: 'Donation History',
                  onTap: () => showDonationHistorySheet(context),
                ),
                const Divider(height: 1),
                _ClassificationToggleRow(
                  current: profile.donorClassification,
                ),
                const Divider(height: 1),
                _VerificationStatusRow(
                  isVerified: profile.isVerified,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── Preferences ────────────────────────────────────────
        const _SectionTitle(title: 'Preferences'),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () => showNotificationSettingsSheet(context),
              ),
              const Divider(height: 1),
              _SettingsRow(
                icon: Icons.location_city,
                label: 'City / Location',
                subtitle: profile.city.isNotEmpty ? profile.city : null,
                onTap: () => showCityDialog(
                  context,
                  ref: ref,
                  currentCity: profile.city,
                ),
              ),
              const Divider(height: 1),
              _RoleSwitcherRow(currentRole: profile.activeRole),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Support ────────────────────────────────────────────
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
        const SizedBox(height: 24),

        // ── Account Actions ────────────────────────────────────
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

  // ── Dialogs & bottom sheets ────────────────────────────────────────────────

  void _showBloodTypePicker(BuildContext context, WidgetRef ref) {
    final bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    final colors = context.colors;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                'Select Blood Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textHigh,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your blood type helps match you with requests.',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textMedium,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: bloodTypes.map((bt) {
                  final isSelected = profile.bloodGroup == bt;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await ref.read(updateProfileFieldProvider)(
                            {'blood_group': bt});
                        if (context.mounted) {
                          context.showSnackBar('Blood type updated to $bt');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          context.showSnackBar(
                              'Update failed: $e', isError: true);
                        }
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                            : colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : colors.border,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        bt,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : colors.textHigh,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Donora+',
      applicationVersion: '1.0.0',
      applicationLegalese: '\u00a9 2025 Donora',
      children: [
        const SizedBox(height: 12),
        const Text(
          'Donora+ connects blood donors and seekers '
          'to save lives in your community.',
        ),
      ],
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerStatefulWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<_ProfileHeader> {
  bool _isUploading = false;

  Future<void> _pickAndUpload(ImageSource source) async {
    setState(() => _isUploading = true);
    try {
      await ref
          .read(uploadProfilePhotoAction)(source);
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

    return Column(
      children: [
        // Editable avatar
        GestureDetector(
          onTap: _isUploading ? null : _showPhotoSourceSheet,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Avatar (with opacity overlay when uploading)
              Opacity(
                opacity: _isUploading ? 0.4 : 1.0,
                child: _LargeProfileAvatar(
                  name: profile.name,
                  photoUrl: profile.profilePhotoUrl,
                ),
              ),

              // Upload spinner
              if (_isUploading)
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),

              // Camera badge (hidden during upload)
              if (!_isUploading)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.card, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Name
        Text(
          profile.name.isNotEmpty ? profile.name : 'Your Name',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.textHigh,
          ),
          textAlign: TextAlign.center,
        ),

        // City
        if (profile.city.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            profile.city,
            style: TextStyle(
              fontSize: 14,
              color: colors.textMedium,
            ),
          ),
        ],
        const SizedBox(height: 10),

        // Badges row
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (profile.isVerified) const VerifiedBadge(),
            if (profile.donorClassification.isNotEmpty)
              DonorStatusChip(
                classification: profile.donorClassification,
              ),
            if (profile.isTopDonor) const _TopDonorBadge(),
          ],
        ),
      ],
    );
  }
}

// ── Large profile avatar ──────────────────────────────────────────────────────

class _LargeProfileAvatar extends StatelessWidget {
  const _LargeProfileAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: colors.primaryContainer,
      );
    }

    return CircleAvatar(
      radius: 48,
      backgroundColor: colors.primaryContainer,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: colors.primary,
        ),
      ),
    );
  }
}

// ── Stats row ───────────────────────────────────────────────────────────

/// Blood Type / Donated / Requested counters — relocated here from the
/// removed Requests bottom-nav tab (design spec §4.2).
class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestCount = ref
        .watch(myRequestCountProvider)
        .whenOrNull(data: (count) => '$count');

    return Row(
      children: [
        Expanded(
          child: StatTile(
            value: profile.bloodGroup.isNotEmpty ? profile.bloodGroup : '—',
            caption: 'Blood Type',
            valueColor: context.colors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            value: '${profile.totalDonations}',
            caption: 'Donated',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            value: requestCount ?? '—',
            caption: 'Requested',
          ),
        ),
      ],
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

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

// ── Settings row ──────────────────────────────────────────────────────────────

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

// ── Classification toggle row ─────────────────────────────────────────────────

class _ClassificationToggleRow extends ConsumerWidget {
  const _ClassificationToggleRow({required this.current});

  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isVolunteer = current == 'volunteer';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.people_outline, size: 22, color: colors.textMedium),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Classification',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textHigh,
              ),
            ),
          ),
          // Segmented toggle
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToggleOption(
                  label: 'Volunteer',
                  selected: isVolunteer,
                  onTap: () {
                    ref.read(updateProfileFieldProvider)(
                        {'donor_classification': 'volunteer'});
                  },
                ),
                _ToggleOption(
                  label: 'Compensated',
                  selected: !isVolunteer,
                  onTap: () {
                    ref.read(updateProfileFieldProvider)(
                        {'donor_classification': 'compensated'});
                  },
                ),
              ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.textMedium,
          ),
        ),
      ),
    );
  }
}

// ── Verification status row ───────────────────────────────────────────────────

class _VerificationStatusRow extends StatelessWidget {
  const _VerificationStatusRow({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: () {
        if (!isVerified) {
          context.pushNamed(RouteNames.verification);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.verified_user_outlined,
                size: 22, color: colors.textMedium),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification Status',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isVerified
                        ? 'Verified'
                        : 'Not verified — tap to submit',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isVerified ? colors.success : colors.urgent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isVerified)
              const VerifiedBadge(compact: true)
            else
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

// ── Role switcher row (SegmentedButton) ──────────────────────────────────────

class _RoleSwitcherRow extends ConsumerWidget {
  const _RoleSwitcherRow({required this.currentRole});

  final String currentRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final activeRole = ref.watch(activeRoleProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.swap_horiz, size: 22, color: colors.textMedium),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Account Role',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textHigh,
              ),
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'seeker', label: Text('Seeker')),
              ButtonSegment(value: 'donor', label: Text('Donor')),
            ],
            selected: {activeRole},
            onSelectionChanged: (selected) {
              ref.read(switchRoleActionProvider)(selected.first);
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logout row ────────────────────────────────────────────────────────────────

class _LogoutRow extends ConsumerWidget {
  const _LogoutRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return InkWell(
      onTap: () => ref.read(logoutActionProvider)(),
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

// ── Delete account row ────────────────────────────────────────────────────────

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
      if (confirmed) {
        final success =
            await ref.read(deleteAccountActionProvider)();
        if (context.mounted && !success) {
          context.showSnackBar(
            'Failed to delete account. Please try again.',
            isError: true,
          );
        }
      }
    });
  }
}

// ── Top donor badge ───────────────────────────────────────────────────────────

class _TopDonorBadge extends StatelessWidget {
  const _TopDonorBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFF9A825).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 14, color: Color(0xFFF9A825)),
          SizedBox(width: 4),
          Text(
            'Top Donor',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB8860B),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
