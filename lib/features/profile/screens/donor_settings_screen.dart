import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../home/providers/home_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/donation_history_sheet.dart';
import '../widgets/profile_dialogs.dart';

/// Donor settings sub-page: blood type, history, classification,
/// hemoglobin, verification status.
class DonorSettingsScreen extends ConsumerWidget {
  const DonorSettingsScreen({super.key});

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
        title: const Text('Donor Settings'),
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
                  // Blood Type
                  _SettingsRow(
                    icon: Icons.bloodtype,
                    label: 'Blood Type',
                    trailing: BloodTypeChip(
                      bloodType: profile.bloodGroup.isNotEmpty
                          ? profile.bloodGroup
                          : '\u2014',
                    ),
                    onTap: () => _showBloodTypePicker(context, ref, profile),
                  ),
                  const Divider(height: 1),

                  // Donation History
                  _SettingsRow(
                    icon: Icons.history,
                    label: 'Donation History',
                    onTap: () => showDonationHistorySheet(context),
                  ),
                  const Divider(height: 1),

                  // Classification Toggle
                  _ClassificationToggleRow(
                    current: profile.donorClassification,
                  ),
                  const Divider(height: 1),

                  // Platelet donation eligibility toggle
                  _PlateletEligibilityRow(
                    enabled: profile.canDonatePlatelets,
                  ),
                  const Divider(height: 1),

                  // Hemoglobin Level
                  _SettingsRow(
                    icon: Icons.bloodtype,
                    label: 'Hemoglobin Level (g/dL)',
                    subtitle: profile.hemoglobinLevel != null
                        ? profile.hemoglobinLevel!.toStringAsFixed(1)
                        : 'Not set \u2014 tap to add',
                    onTap: () => showEditHemoglobinDialog(
                      context,
                      ref: ref,
                      currentValue: profile.hemoglobinLevel,
                    ),
                  ),
                  const Divider(height: 1),

                  // Verification Status
                  _VerificationStatusRow(
                    isVerified: profile.isVerified,
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

  void _showBloodTypePicker(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
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
                        color: isSelected ? colors.primary : colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? colors.primary : colors.border,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        bt,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color:
                              isSelected ? Colors.white : colors.textHigh,
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

// ── Classification toggle row ────────────────────────────────────────────────

class _ClassificationToggleRow extends ConsumerWidget {
  const _ClassificationToggleRow({required this.current});

  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isVolunteer = current == 'volunteer';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, size: 20, color: colors.textMedium),
              const SizedBox(width: 10),
              Text(
                'Classification',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.textHigh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
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
                    label: 'Volunteer',
                    selected: isVolunteer,
                    onTap: () {
                      ref.read(updateProfileFieldProvider)(
                          {'donor_classification': 'volunteer'});
                    },
                  ),
                ),
                Expanded(
                  child: _ToggleOption(
                    label: 'Compensated',
                    selected: !isVolunteer,
                    onTap: () {
                      ref.read(updateProfileFieldProvider)(
                          {'donor_classification': 'compensated'});
                    },
                  ),
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

// ── Platelet eligibility toggle ───────────────────────────────────────────────

class _PlateletEligibilityRow extends ConsumerStatefulWidget {
  const _PlateletEligibilityRow({required this.enabled});

  final bool enabled;

  @override
  ConsumerState<_PlateletEligibilityRow> createState() =>
      _PlateletEligibilityRowState();
}

class _PlateletEligibilityRowState
    extends ConsumerState<_PlateletEligibilityRow> {
  bool _isUpdating = false;

  Future<void> _onChanged(bool value) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      await ref.read(updateProfileFieldProvider)(
          {'can_donate_platelets': value});
      if (mounted) {
        context.showSnackBar(
          value
              ? 'Platelet donation eligibility enabled.'
              : 'Platelet donation eligibility disabled.',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Could not update eligibility: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 22, color: colors.textMedium),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platelet Donation Eligible',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textHigh,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Platelet donation requires apheresis-capable '
                  'centers \u2014 only enable if you\'re able to donate '
                  'this way.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colors.textMedium,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: widget.enabled,
            activeThumbColor: colors.primary,
            onChanged: _isUpdating ? null : _onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Verification status row ──────────────────────────────────────────────────

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
                        : 'Not verified! Tap to submit',
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
