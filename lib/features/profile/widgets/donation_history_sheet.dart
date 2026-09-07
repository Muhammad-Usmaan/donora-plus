import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../home/providers/home_providers.dart';
import '../providers/donation_history_provider.dart';

/// Bottom sheet for the "Donation History" donor-settings row.
///
/// Shows a summary strip (total donations, last donation, cooldown) followed
/// by the list of requests the donor fulfilled. Tapping a record opens the
/// request detail screen.
void showDonationHistorySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _DonationHistorySheet(),
  );
}

class _DonationHistorySheet extends ConsumerWidget {
  const _DonationHistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profileAsync = ref.watch(userProfileProvider);
    final historyAsync = ref.watch(donationHistoryProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: ListView(
            controller: scrollController,
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
                'Donation History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textHigh,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Donations you made through Donora+.',
                style: TextStyle(fontSize: 13, color: colors.textMedium),
              ),
              const SizedBox(height: 20),

              // ── Summary strip ────────────────────────────────────
              profileAsync.when(
                loading: () => const SizedBox(
                  height: 76,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (profile) => _DonationSummaryStrip(profile: profile),
              ),
              const SizedBox(height: 20),

              // ── Records ──────────────────────────────────────────
              historyAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const _HistoryEmptyState(
                  icon: Icons.error_outline,
                  message:
                      'Could not load history. Pull down to refresh later.',
                ),
                data: (records) {
                  if (records.isEmpty) {
                    return const _HistoryEmptyState(
                      icon: Icons.volunteer_activism_outlined,
                      message:
                          'No donations recorded yet. When you fulfil a '
                          'request it will appear here.',
                    );
                  }
                  return Column(
                    children: [
                      for (final record in records)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DonationRecordCard(record: record),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Total / last donation / next eligible summary.
class _DonationSummaryStrip extends ConsumerWidget {
  const _DonationSummaryStrip({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final cooldown = ref.watch(cooldownProvider);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              icon: Icons.favorite,
              iconColor: colors.primary,
              value: '${profile.totalDonations}',
              label: 'Donations',
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: colors.border,
            indent: 14,
            endIndent: 14,
          ),
          Expanded(
            child: _SummaryStat(
              icon: Icons.event_available,
              iconColor: colors.secondary,
              value: profile.mostRecentDonationDate != null
                  ? Formatters.dateShort(profile.mostRecentDonationDate!)
                  : '\u2014',
              label: 'Last donation',
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: colors.border,
            indent: 14,
            endIndent: 14,
          ),
          Expanded(
            child: _SummaryStat(
              icon: cooldown.eligible ? Icons.check_circle : Icons.schedule,
              iconColor: cooldown.eligible ? colors.success : colors.warning,
              value: cooldown.eligible ? 'Eligible' : '${cooldown.daysRemaining}d',
              label: cooldown.eligible ? 'to donate' : 'until eligible',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textHigh,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colors.textMedium),
          ),
        ],
      ),
    );
  }
}

/// A single fulfilled-donation row.
class _DonationRecordCard extends StatelessWidget {
  const _DonationRecordCard({required this.record});

  final DonationRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      onTap: () {
        Navigator.of(context).pop();
        context.pushNamed(
          RouteNames.requestDetail,
          pathParameters: {'id': record.requestId},
        );
      },
      child: Row(
        children: [
          if (record.bloodGroup.isNotEmpty) BloodTypeChip(bloodType: record.bloodGroup),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.hospitalName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textHigh,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    record.city,
                    if (record.fulfilledAt != null)
                      Formatters.dateShort(record.fulfilledAt!),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 12.5, color: colors.textMedium),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 20, color: colors.textMedium),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 36, color: colors.textMedium),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.textMedium, height: 1.5),
          ),
        ],
      ),
    );
  }
}
