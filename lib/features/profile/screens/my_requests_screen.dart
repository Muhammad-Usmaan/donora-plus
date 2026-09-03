import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/reason_pill.dart';
import '../../../core/widgets/urgent_request_badge.dart';
import '../../requests/providers/requests_list_provider.dart';
import '../providers/profile_providers.dart';

/// Dedicated screen listing all blood requests created by the current user.
///
/// Reached from the Profile screen's "Request History" row. Each card shows
/// a status badge with icon, blood-type chip, urgency badge, expiry /
/// planned-date label, and reason pill.
class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final requestsAsync = ref.watch(myRequestsListProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text('Request History'),
        centerTitle: false,
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const _EmptyView();
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: requests.length,
            itemBuilder: (context, index) =>
                _MyRequestCard(request: requests[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: colors.textMedium),
                const SizedBox(height: 12),
                Text(
                  'Could not load requests',
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
                  style: TextStyle(fontSize: 12, color: colors.textMedium),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => ref.invalidate(myRequestsListProvider),
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

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

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
              child: PhosphorIcon(
                PhosphorIconsRegular.clockCounterClockwise,
                size: 40,
                color: colors.secondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No requests yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textHigh,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you create a blood request it will\nappear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colors.textMedium,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.pushNamed(RouteNames.requestCreate),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Request'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Request card ─────────────────────────────────────────────────────────────

class _MyRequestCard extends StatelessWidget {
  const _MyRequestCard({required this.request});

  final RequestListItem request;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.pushNamed(
        RouteNames.requestDetail,
        pathParameters: {'id': request.id},
      ),
      borderColor: request.isUrgent && request.isActive
          ? colors.urgent.withValues(alpha: 0.4)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: urgency / planned badge, status chip, expiry label.
          Row(
            children: [
              if (request.isUrgent) ...[
                const UrgentRequestBadge(compact: true),
                const SizedBox(width: 6),
              ] else if (request.plannedDate != null) ...[
                const _PlannedBadge(),
                const SizedBox(width: 6),
              ],
              _StatusChip(request: request),
              const Spacer(),
              if (request.isActive && request.isUrgent)
                _ExpiryLabel(expiresAt: request.expiresAt, isUrgent: true)
              else if (request.isActive &&
                  !request.isUrgent &&
                  request.plannedDate != null)
                _ExpiryLabel(
                  expiresAt: request.expiresAt,
                  isUrgent: false,
                  plannedDate: request.plannedDate!,
                )
              else
                Text(
                  Formatters.timeAgo(request.createdAt),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.textMedium,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Blood type + units.
          Row(
            children: [
              if (request.bloodGroup.isNotEmpty)
                BloodTypeChip(bloodType: request.bloodGroup),
              const SizedBox(width: 8),
              Text(
                '${request.unitsNeeded} unit${request.unitsNeeded == 1 ? '' : 's'}',
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Reason pill.
          Row(children: [ReasonPill(reason: request.reason)]),
          const SizedBox(height: 10),

          // Hospital.
          Row(
            children: [
              Icon(
                Icons.local_hospital_outlined,
                size: 14,
                color: colors.textMedium,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request.hospitalName.isEmpty
                      ? 'Hospital not specified'
                      : request.hospitalName,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.textMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // City + chevron.
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: colors.textMedium,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request.city.isEmpty ? 'City not set' : request.city,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.textMedium,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: colors.textMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Planned badge ────────────────────────────────────────────────────────────

class _PlannedBadge extends StatelessWidget {
  const _PlannedBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_outlined, size: 12, color: c.secondary),
          const SizedBox(width: 4),
          Text(
            'Planned',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.request});

  final RequestListItem request;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Map DB status to display label, color, and Phosphor icon.
    // Uses only existing design-system color tokens — no new hex values.
    final String label;
    final Color color;
    final IconData icon;

    switch (request.status) {
      case 'active':
        label = 'Pending';
        color = colors.warning;
        icon = PhosphorIconsRegular.clock;
      case 'fulfilled':
        label = 'Fulfilled';
        color = colors.success;
        icon = PhosphorIconsRegular.checkCircle;
      case 'expired':
        label = 'Expired';
        color = colors.textMedium;
        icon = PhosphorIconsRegular.xCircle;
      case 'closed':
        label = 'Cancelled';
        color = colors.textMedium;
        icon = PhosphorIconsRegular.xCircle;
      default:
        label = request.statusLabel;
        color = colors.textMedium;
        icon = PhosphorIconsRegular.circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expiry / planned-date label ──────────────────────────────────────────────

class _ExpiryLabel extends StatelessWidget {
  const _ExpiryLabel({
    required this.expiresAt,
    required this.isUrgent,
    this.plannedDate,
  });

  final DateTime expiresAt;
  final bool isUrgent;
  final DateTime? plannedDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!isUrgent && plannedDate != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_outlined, size: 12, color: colors.secondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                Formatters.neededBy(plannedDate!),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.secondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    final countdown = Formatters.expiresCountdown(expiresAt);
    final isLow = expiresAt.difference(DateTime.now()).inHours < 6;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLow ? colors.urgentContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLow ? Icons.warning_amber_rounded : Icons.schedule,
            size: 12,
            color: isLow ? colors.urgent : colors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            countdown,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isLow ? colors.urgent : colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
