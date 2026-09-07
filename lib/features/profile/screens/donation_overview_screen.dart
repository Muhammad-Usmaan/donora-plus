import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/donation_type_badge.dart';
import '../../home/providers/home_providers.dart';
import '../providers/profile_providers.dart';

import '../widgets/profile_dialogs.dart';

/// Donation overview sub-page: stats card + schedule card.
class DonationOverviewScreen extends ConsumerWidget {
  const DonationOverviewScreen({super.key});

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
        title: const Text('Donation Overview'),
        centerTitle: false,
      ),
      body: profileAsync.when(
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Donation Stats Card
            _DonationStatsCard(
              profile: profile,
              onGoalTap: () => showGoalEditSheet(
                context,
                ref: ref,
                currentGoal: profile.donationGoal,
              ),
            ),
            const SizedBox(height: 16),

            // Eligibility Card
            const _EligibilityCard(),
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
}

// ── Donation Stats Card ──────────────────────────────────────────────────────

class _DonationStatsCard extends ConsumerWidget {
  const _DonationStatsCard({required this.profile, required this.onGoalTap});
  final UserProfile profile;
  final VoidCallback onGoalTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final statsAsync = ref.watch(feedbackStatsProvider);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Donation Goal + Blood Type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onGoalTap,
                    child: _buildGoalSection(context),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Blood Type: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textMedium,
                        ),
                      ),
                      BloodTypeChip(
                        bloodType: profile.bloodGroup.isNotEmpty
                            ? profile.bloodGroup
                            : '\u2014',
                        compact: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Divider
            Container(
              width: 1,
              height: 60,
              color: colors.border,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),

            // Right: Last Donation + Appreciations
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Donation',
                    style: TextStyle(fontSize: 12, color: colors.textMedium),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.mostRecentDonationDate != null
                        ? Formatters.dateShort(profile.mostRecentDonationDate!)
                        : '\u2014',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Appreciation',
                    style: TextStyle(fontSize: 12, color: colors.textMedium),
                  ),
                  const SizedBox(height: 4),
                  statsAsync.when(
                    data: (stats) {
                      final appreciated = stats?['appreciated_count'] ?? 0;
                      final totalFeedback = stats?['total_feedback_count'] ?? 0;
                      final avgRating =
                          stats?['average_star_rating'] as double?;
                      // Zero-feedback state: show "No feedback yet" instead of "0/0".
                      if (totalFeedback == 0) {
                        return Text(
                          'No feedback yet',
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: colors.textMedium,
                          ),
                        );
                      }
                      return Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star, size: 14, color: colors.warning),
                              const SizedBox(width: 4),
                              Text(
                                avgRating?.toStringAsFixed(1) ?? '—',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textHigh,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '$appreciated/$totalFeedback appreciated',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () => SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.textMedium,
                      ),
                    ),
                    error: (_, __) => Text(
                      '\u2014',
                      style: TextStyle(fontSize: 14, color: colors.textMedium),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSection(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onGoalTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Donation Goal',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textMedium,
            ),
          ),
          const SizedBox(height: 4),
          if (profile.donationGoal != null)
            Text(
              '${profile.donationGoal}',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: colors.textHigh,
                height: 1.0,
              ),
            )
          else
            Text(
              'Set your goal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textMedium,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Eligibility Card ─────────────────────────────────────────────────────────

class _EligibilityCard extends ConsumerWidget {
  const _EligibilityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final eligibilityAsync = ref.watch(donationEligibilityProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Donation Eligibility',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textMedium,
            ),
          ),
          const SizedBox(height: 12),
          eligibilityAsync.when(
            data: (eligibility) {
              if (eligibility == null) {
                // Never donated either type.
                return _buildNeverDonatedRow(colors);
              }
              return Column(
                children: [
                  _buildTypeRow(
                    context: context,
                    donationType: 'blood',
                    nextDate: eligibility.nextWholeBloodDate,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(height: 1, color: colors.border),
                  ),
                  _buildTypeRow(
                    context: context,
                    donationType: 'platelet',
                    nextDate: eligibility.nextPlateletDate,
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Text(
              '\u2014',
              style: TextStyle(fontSize: 14, color: colors.textMedium),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeverDonatedRow(AppColors colors) {
    return Row(
      children: [
        Icon(Icons.info_outline, size: 18, color: colors.textMedium),
        const SizedBox(width: 10),
        Text(
          'No donation history',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.textMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeRow({
    required BuildContext context,
    required String donationType,
    required DateTime? nextDate,
  }) {
    final colors = context.colors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isEligible = nextDate == null ||
        !DateTime(nextDate.year, nextDate.month, nextDate.day)
            .isAfter(today);

    final statusColor = isEligible ? colors.success : colors.warning;
    final statusIcon =
        isEligible ? PhosphorIconsRegular.checkCircle : PhosphorIconsRegular.clock;
    final statusLabel = isEligible
        ? 'Eligible now'
        : '${Formatters.dateShort(nextDate)} \u00b7 ${Formatters.relativeDate(nextDate)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: DonationTypeBadge(
              donationType: donationType,
              compact: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                PhosphorIcon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
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
