import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/constants/request_reasons.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/reason_pill.dart';
import '../../../core/widgets/urgent_request_badge.dart';
import '../../../core/widgets/verified_badge.dart';
import '../providers/home_providers.dart';

/// Seeker home view — urgent CTA, nearby verified donors, active requests.
class SeekerHomeView extends ConsumerWidget {
  const SeekerHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
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
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      context.colors.urgent,
                      context.colors.urgent.withValues(alpha: 0.65),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.urgent.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const PhosphorIcon(
                        PhosphorIconsFill.drop,
                        color: Colors.white,
                        size: 26,
                      ),
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
                    const PhosphorIcon(
                      PhosphorIconsRegular.caretRight,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Ask Donora AI ──────────────────────────────────────
          // Single entry point to the AI assistant — teal tint so it
          // reads as secondary to the solid-red hero CTA above it.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => context.pushNamed(RouteNames.chatbot),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.colors.secondary
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: PhosphorIcon(
                        PhosphorIconsRegular.sparkle,
                        color: context.colors.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ask Donora AI',
                            style: context.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Get quick answers about donating or '
                            'requesting blood.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PhosphorIcon(
                      PhosphorIconsRegular.caretRight,
                      color: context.colors.secondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Nearby Verified Donors ────────────────────────────────
          _SectionHeader(
            title: 'Nearby Verified Donors',
            onSeeAll: () => context.pushNamed(RouteNames.donors),
          ),
          const SizedBox(height: 12),
          _NearbyDonorsRow(),
          const SizedBox(height: 24),

          // ── Your Active Requests ──────────────────────────────────
          _SectionHeader(
            title: 'Your Active Requests',
            onSeeAll: () => context.pushNamed(RouteNames.requests),
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
// Section header with "See All" link
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: context.textTheme.titleLarge),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See All',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.colors.primary,
                  ),
                ],
              ),
            ),
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
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

class _ActiveRequestCard extends ConsumerWidget {
  const _ActiveRequestCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final requestId = request['id'] as String? ?? '';
    final bloodGroup = request['blood_group'] as String? ?? '';
    final city = request['city'] as String? ?? '';
    final isUrgent = request['is_urgent'] as bool? ?? false;
    final units = request['units_needed'] as int? ?? 1;
    final createdAt =
        DateTime.tryParse(request['created_at'] as String? ?? '');
    final reason = RequestReason.fromValue(request['reason'] as String?);

    // Live responder count — falls back to 0 while loading.
    final responders =
        ref.watch(requestResponseCountProvider(requestId)).valueOrNull ?? 0;

    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.requestDetail,
        pathParameters: {'id': requestId},
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Blood type + units + urgency.
            Row(
              children: [
                if (bloodGroup.isNotEmpty)
                  BloodTypeChip(bloodType: bloodGroup),
                const SizedBox(width: 8),
                Text(
                  '$units unit${units == 1 ? '' : 's'}',
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: colors.textMedium),
                ),
                const Spacer(),
                if (isUrgent) const UrgentRequestBadge(compact: true),
              ],
            ),
            const SizedBox(height: 12),

            // Location.
            Row(
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.mapPin,
                  size: 16,
                  color: colors.textMedium,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    city.isEmpty ? 'City not set' : city,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reason pill + posted time.
            Row(
              children: [
                ReasonPill(reason: reason),
                const Spacer(),
                if (createdAt != null)
                  Text(
                    Formatters.timeAgo(createdAt),
                    style: context.textTheme.bodySmall
                        ?.copyWith(color: colors.textMedium),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Responders + navigation hint.
            Row(
              children: [
                Text(
                  responders == 1
                      ? '1 donor responded'
                      : '$responders donors responded',
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: colors.textMedium),
                ),
                const Spacer(),
                PhosphorIcon(
                  PhosphorIconsRegular.caretRight,
                  size: 20,
                  color: colors.textMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
