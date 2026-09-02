import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/reason_pill.dart';
import '../../../core/widgets/urgent_request_badge.dart';
import '../providers/requests_list_provider.dart';

/// Requests list screen — browse community requests or manage your own.
///
/// Segmented All / Mine scope switch (server-side query), blood-type chips
/// and urgent-only toggle (client-side filters), and a FAB to create a new
/// request.
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final requestsAsync = ref.watch(requestsListProvider);
    final filter = ref.watch(requestListFilterProvider);
    final requests = ref.watch(filteredRequestsProvider);

    final hasActiveFilters = filter.isFilteringBlood || filter.urgentOnly;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text('Blood Requests'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RouteNames.requestCreate),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: Column(
        children: [
          // ── Scope switch (All / Mine) ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _ScopeSwitch(
              scope: filter.scope,
              onChanged: (scope) =>
                  ref.read(requestListFilterProvider.notifier).setScope(scope),
            ),
          ),

          // ── Blood type + urgent filters ─────────────────────────
          SizedBox(
            height: 44,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final type in const [
                    'A+',
                    'A-',
                    'B+',
                    'B-',
                    'AB+',
                    'AB-',
                    'O+',
                    'O-',
                  ]) ...[
                    BloodTypeChip(
                      bloodType: type,
                      selected: filter.selectedBloodTypes.contains(type),
                      onTap: () => ref
                          .read(requestListFilterProvider.notifier)
                          .toggleBloodType(type),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _UrgentOnlyPill(
                    selected: filter.urgentOnly,
                    onTap: () => ref
                        .read(requestListFilterProvider.notifier)
                        .setUrgentOnly(!filter.urgentOnly),
                  ),
                ],
              ),
            ),
          ),

          // ── Result count + clear ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    requestsAsync.hasValue
                        ? '${requests.length} '
                              '${requests.length == 1 ? 'request' : 'requests'}'
                        : ' ',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.textMedium,
                    ),
                  ),
                ),
                if (hasActiveFilters)
                  TextButton.icon(
                    onPressed: () => ref
                        .read(requestListFilterProvider.notifier)
                        .clearFilters(),
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                    label: const Text('Clear filters'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),

          // ── List ────────────────────────────────────────────────
          Expanded(
            child: requestsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(requestsListProvider),
              ),
              data: (allRequests) {
                if (allRequests.isEmpty) {
                  return _EmptyView(
                    icon: filter.scope == RequestsScope.mine
                        ? Icons.volunteer_activism_outlined
                        : Icons.bloodtype_outlined,
                    title: filter.scope == RequestsScope.mine
                        ? 'No requests yet'
                        : 'No open requests right now',
                    message: filter.scope == RequestsScope.mine
                        ? 'Create a request when you or someone nearby needs blood.'
                        : 'Active requests from your community will appear here.',
                  );
                }
                if (requests.isEmpty) {
                  return _EmptyView(
                    icon: Icons.search_off,
                    title: 'No requests match your filters',
                    message:
                        'Try a different blood type or clear the urgent filter.',
                    actionLabel: 'Clear filters',
                    onAction: () => ref
                        .read(requestListFilterProvider.notifier)
                        .clearFilters(),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: requests.length,
                  itemBuilder: (context, index) =>
                      _RequestCard(request: requests[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scope switch (All / Mine) ─────────────────────────────────────────────────

class _ScopeSwitch extends StatelessWidget {
  const _ScopeSwitch({required this.scope, required this.onChanged});

  final RequestsScope scope;
  final ValueChanged<RequestsScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScopePill(
              label: 'All Requests',
              icon: Icons.public,
              isActive: scope == RequestsScope.all,
              onTap: () => onChanged(RequestsScope.all),
            ),
          ),
          Expanded(
            child: _ScopePill(
              label: 'My Requests',
              icon: Icons.person_outline,
              isActive: scope == RequestsScope.mine,
              onTap: () => onChanged(RequestsScope.mine),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopePill extends StatelessWidget {
  const _ScopePill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? colors.primary : colors.textMedium,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: isActive ? colors.primary : colors.textMedium,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Urgent-only filter pill ───────────────────────────────────────────────────

class _UrgentOnlyPill extends StatelessWidget {
  const _UrgentOnlyPill({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.urgent : colors.urgentContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt_rounded,
              size: 16,
              color: selected ? Colors.white : colors.urgent,
            ),
            const SizedBox(width: 6),
            Text(
              'Urgent only',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : colors.urgent,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Request card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final RequestListItem request;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
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
          // Header row: urgency, status, expiry / posted time.
          Row(
            children: [
              if (request.isUrgent) ...[
                const UrgentRequestBadge(compact: true),
                const SizedBox(width: 6),
              ],
              _StatusChip(request: request),
              const Spacer(),
              if (request.isActive && request.isUrgent)
                _ListExpiryLabel(expiresAt: request.expiresAt, isUrgent: true)
              else if (request.isActive &&
                  !request.isUrgent &&
                  request.plannedDate != null)
                _ListExpiryLabel(
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

          // Blood group + units.
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

          // Hospital + city.
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

          // Notes.
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.notes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.textMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Colored status pill matching the detail screen's status colors.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.request});

  final RequestListItem request;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final Color color;
    switch (request.status) {
      case 'fulfilled':
        color = colors.secondary;
      case 'closed':
        color = colors.textMedium;
      case 'expired':
        color = colors.warning;
      case 'active':
        color = request.isExpired ? colors.warning : colors.success;
      default:
        color = colors.textMedium;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        request.statusLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Empty & error states ──────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: colors.textMedium),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.textMedium,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 44, color: colors.textMedium),
            const SizedBox(height: 12),
            Text(
              'Could not load requests',
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.textMedium,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Expiry label for request list cards
// ═══════════════════════════════════════════════════════════════════════════════

class _ListExpiryLabel extends StatelessWidget {
  const _ListExpiryLabel({
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
