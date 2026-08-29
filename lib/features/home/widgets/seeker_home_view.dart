import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/urgent_request_badge.dart';
import '../../../core/widgets/verified_badge.dart';
import '../providers/home_providers.dart';

/// Seeker home view — urgent CTA, nearby verified donors, active requests.
class SeekerHomeView extends ConsumerWidget {
  const SeekerHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Urgent CTA ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () =>
                  context.pushNamed(RouteNames.requestCreate),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.urgent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bloodtype,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request Blood Now',
                            style: context.textTheme.titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Find donors near you instantly',
                            style: context.textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Nearby Verified Donors ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Nearby Verified Donors',
              style: context.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          _NearbyDonorsRow(),
          const SizedBox(height: 24),

          // ── Your Active Requests ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Your Active Requests',
              style: context.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          _ActiveRequestsList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Nearby donors horizontal scroll
// ═══════════════════════════════════════════════════════════════════════════════

class _NearbyDonorsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donorsAsync = ref.watch(nearbyDonorsProvider);

    return donorsAsync.when(
      loading: () => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) {
        final message = e.isNetworkError
            ? 'No internet connection. Check your network.'
            : 'Unable to load donors.';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(message, style: context.textTheme.bodyMedium),
              ),
              TextButton.icon(
                onPressed: () => ref.invalidate(nearbyDonorsProvider),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      },
      data: (donors) {
        if (donors.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No verified donors in your area yet.',
              style: context.textTheme.bodyMedium,
            ),
          );
        }

        return SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: donors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _DonorCard(
              donor: donors[i],
            ),
          ),
        );
      },
    );
  }
}

class _DonorCard extends StatelessWidget {
  const _DonorCard({required this.donor});

  final Map<String, dynamic> donor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = donor['name'] as String? ?? 'Donor';
    final bloodGroup = donor['blood_group'] as String? ?? '';
    final city = donor['city'] as String? ?? '';

    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.donorDetail,
        pathParameters: {'id': donor['id'] as String? ?? ''},
      ),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Photo placeholder
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 22,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name.split(' ').first,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelLarge,
                  ),
                ),
                if (donor['is_verified'] == true) ...[
                  const SizedBox(width: 2),
                  const VerifiedBadge(compact: true),
                ],
              ],
            ),
            const SizedBox(height: 4),
            if (bloodGroup.isNotEmpty)
              BloodTypeChip(bloodType: bloodGroup)
            else
              Text(
                city,
                style: context.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Active requests list
// ═══════════════════════════════════════════════════════════════════════════════

class _ActiveRequestsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(activeRequestsProvider);

    return requestsAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) {
        final message = e.isNetworkError
            ? 'No internet connection. Check your network.'
            : 'Unable to load requests.';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(message, style: context.textTheme.bodyMedium),
              ),
              TextButton.icon(
                onPressed: () => ref.invalidate(activeRequestsProvider),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      },
      data: (requests) {
        if (requests.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'You have no active requests.',
              style: context.textTheme.bodyMedium,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: requests
                .map((r) => _ActiveRequestCard(request: r))
                .toList(),
          ),
        );
      },
    );
  }
}

class _ActiveRequestCard extends StatelessWidget {
  const _ActiveRequestCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bloodGroup = request['blood_group'] as String? ?? '';
    final city = request['city'] as String? ?? '';
    final isUrgent = request['is_urgent'] as bool? ?? false;

    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.requestDetail,
        pathParameters: {'id': request['id'] as String? ?? ''},
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Row(
          children: [
            // Blood type
            if (bloodGroup.isNotEmpty) BloodTypeChip(bloodType: bloodGroup),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isUrgent) ...[
                        const UrgentRequestBadge(compact: true),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          city,
                          style: context.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '0 donors responded',
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textMedium),
          ],
        ),
      ),
    );
  }
}
