import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../home/providers/home_providers.dart';
import '../providers/profile_providers.dart';

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
              onGoalTap: () => _showGoalEditSheet(context, ref, profile),
            ),
            const SizedBox(height: 16),

            // Schedule Card
            const _ScheduleCard(),
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

  void _showGoalEditSheet(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    final colors = context.colors;
    final controller = TextEditingController(
      text: profile.donationGoal?.toString() ?? '',
    );

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
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
                      'Set Donation Goal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textHigh,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How many donations would you like to reach?',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 15',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) {
                            Navigator.of(ctx).pop();
                            return;
                          }
                          final goal = int.tryParse(text);
                          if (goal == null || goal <= 0) {
                            context.showSnackBar(
                              'Enter a positive number',
                              isError: true,
                            );
                            return;
                          }
                          Navigator.of(ctx).pop();
                          try {
                            await ref.read(updateProfileFieldProvider)(
                                {'donation_goal': goal});
                            if (context.mounted) {
                              context.showSnackBar(
                                  'Donation goal updated to $goal');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              context.showSnackBar(
                                  'Update failed: $e', isError: true);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save Goal'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.mostRecentDonationDate != null
                        ? Formatters.dateShort(
                            profile.mostRecentDonationDate!)
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
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 4),
                  statsAsync.when(
                    data: (stats) {
                      final appreciated = stats?['appreciated_count'] ?? 0;
                      final totalFeedback = stats?['total_feedback_count'] ?? 0;
                      final avgRating = stats?['average_star_rating'] as double?;
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
                      return Row(
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
                          const SizedBox(width: 8),
                          Text(
                            '$appreciated/$totalFeedback appreciated',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textMedium,
                            ),
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
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textMedium,
                      ),
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

// ── Schedule Card ────────────────────────────────────────────────────────────

class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final dateAsync = ref.watch(nextDonationEligibleDateProvider);

    return AppCard(
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today,
              size: 22,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next donation schedule',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textMedium,
                  ),
                ),
                const SizedBox(height: 4),
                dateAsync.when(
                  data: (date) {
                    if (date == null) {
                      return Text(
                        'Not yet scheduled',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textHigh,
                        ),
                      );
                    }
                    return Text(
                      '${Formatters.dateShort(date)} \u00b7 ${Formatters.relativeDate(date)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textHigh,
                      ),
                    );
                  },
                  loading: () => Text(
                    'Loading\u2026',
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.textMedium,
                    ),
                  ),
                  error: (_, __) => Text(
                    '\u2014',
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.textMedium,
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
