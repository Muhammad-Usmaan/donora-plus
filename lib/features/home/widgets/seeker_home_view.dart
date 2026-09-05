import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/constants/request_reasons.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/donation_type_badge.dart';
import '../../../core/widgets/reason_pill.dart';
import '../../../core/widgets/urgent_request_badge.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../chatbot/widgets/ask_donora_ai_card.dart';
import 'donation_type_tabs.dart';
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
          const AskDonoraAiCard(),
          const SizedBox(height: 24),

          // ── Blood / Platelets filter ────────────────────────────────
          const DonationTypeTabs(),
          const SizedBox(height: 16),

          // ── Donation in Progress (seeker only, hidden when empty) ─
          const _DonationInProgressSection(),

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
        height: 195,
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
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

  String _getInitials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2);
    if (words.isEmpty) return '?';
    return words.map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = donor['name'] as String? ?? 'Donor';
    final bloodGroup = donor['blood_group'] as String? ?? '';
    final city = donor['city'] as String? ?? '';
    final photoUrl = donor['profile_photo_url'] as String?;
    final isVerified = donor['is_verified'] == true;
    final isTopDonor = donor['is_top_donor'] == true;
    final classification =
        donor['donor_classification'] as String? ?? 'volunteer';
    final isVolunteer = classification == 'volunteer';

    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.donorDetail,
        pathParameters: {'id': donor['id'] as String? ?? ''},
      ),
      child: Container(
        width: 156,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top row: Blood type pill + Top Donor / Verified badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (bloodGroup.isNotEmpty)
                  BloodTypeChip(bloodType: bloodGroup, compact: true)
                else
                  const SizedBox(width: 16),
                if (isTopDonor)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF9A825).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 13,
                      color: Color(0xFFF9A825),
                    ),
                  )
                else if (isVerified)
                  const VerifiedBadge(compact: true)
                else
                  const SizedBox(width: 16),
              ],
            ),
            const SizedBox(height: 6),

            // Avatar with online / verified green indicator dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primaryContainer,
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: (photoUrl != null && photoUrl.isNotEmpty)
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(
                                _getInitials(name),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              _getInitials(name),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: colors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.card, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Name
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 2),

            // City / Location
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 12,
                  color: colors.textMedium,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    city.isNotEmpty ? city : 'Pakistan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.textMedium,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Classification pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isVolunteer ? colors.volunteer : colors.compensated)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVolunteer ? Icons.favorite : Icons.directions_walk,
                    size: 10.5,
                    color: isVolunteer ? colors.volunteer : colors.compensated,
                  ),
                  const SizedBox(width: 3.5),
                  Text(
                    isVolunteer ? 'Volunteer' : 'Compensated',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isVolunteer
                          ? colors.volunteer
                          : colors.compensated,
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// Expiry label — "Expires in Xh" for urgent, "Needed by [date]" for planned
// ═══════════════════════════════════════════════════════════════════════════════

class _ExpiryLabel extends StatelessWidget {
  const _ExpiryLabel({
    required this.expiresAt,
    required this.isUrgent,
    this.plannedDate,
  });

  final DateTime? expiresAt;
  final bool isUrgent;
  final DateTime? plannedDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!isUrgent && plannedDate != null) {
      // Planned: show "Needed by [date]"
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

    if (isUrgent && expiresAt != null) {
      // Urgent: show countdown
      final countdown = Formatters.expiresCountdown(expiresAt!);
      final isLow = expiresAt!.difference(DateTime.now()).inHours < 6;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isLow
              ? colors.urgentContainer
              : colors.primaryContainer,
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

    return const SizedBox.shrink();
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
                .map((r) => _ActiveRequestCard(
                      key: ValueKey(r['id'] as String? ?? ''),
                      request: r,
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class _ActiveRequestCard extends ConsumerWidget {
  const _ActiveRequestCard({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final requestId = request['id'] as String? ?? '';
    final bloodGroup = request['blood_group'] as String? ?? '';
    final donationType = request['donation_type'] as String? ?? 'blood';
    final city = request['city'] as String? ?? '';
    final hospitalName = request['hospital_name'] as String? ?? '';
    final patientName = request['patient_name'] as String? ?? '';
    final isUrgent = request['is_urgent'] as bool? ?? false;
    final units = request['units_needed'] as int? ?? 1;
    final createdAt =
        DateTime.tryParse(request['created_at'] as String? ?? '');
    final expiresAt =
        DateTime.tryParse(request['expires_at'] as String? ?? '');
    final plannedDate =
        DateTime.tryParse(request['planned_date'] as String? ?? '');
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
            // Donation type badge + blood type + units + urgency / expiry label.
            Row(
              children: [
                DonationTypeBadge(donationType: donationType, compact: true),
                const SizedBox(width: 6),
                if (bloodGroup.isNotEmpty) BloodTypeChip(bloodType: bloodGroup),
                const SizedBox(width: 8),
                Text(
                  '$units unit${units == 1 ? '' : 's'}',
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: colors.textMedium),
                ),
                const Spacer(),
                if (isUrgent && expiresAt != null)
                  _ExpiryLabel(expiresAt: expiresAt, isUrgent: true)
                else if (!isUrgent && plannedDate != null)
                  _ExpiryLabel(expiresAt: expiresAt, isUrgent: false, plannedDate: plannedDate)
                else if (isUrgent)
                  const UrgentRequestBadge(compact: true),
              ],
            ),

            // Patient name (if available)
            if (patientName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.favorite_border, size: 13, color: colors.textMedium),
                  const SizedBox(width: 4),
                  Text(
                    'Patient: $patientName',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.textMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),

            // Location (tappable).
            GestureDetector(
              onTap: () {
                final lat = request['latitude'] as double?;
                final lng = request['longitude'] as double?;
                final loc = hospitalName.isNotEmpty ? '$hospitalName, $city' : city;
                
                if (lat != null && lng != null) {
                  MapUtils.openPlaceMarker(
                    lat, 
                    lng, 
                    label: hospitalName.isNotEmpty ? hospitalName : city,
                  );
                } else if (loc.isNotEmpty) {
                  MapUtils.openNavigationByName(loc);
                }
              },
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hospitalName.isNotEmpty
                          ? '$hospitalName, $city'
                          : city.isEmpty
                              ? 'City not set'
                              : city,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Icon(Icons.open_in_new, size: 13, color: colors.primary),
                ],
              ),
            ),
            const SizedBox(height: 10),

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
            const SizedBox(height: 10),

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

// ═══════════════════════════════════════════════════════════════════════════════
// Donation in Progress — shown only when seeker has accepted requests
// ═══════════════════════════════════════════════════════════════════════════════

class _DonationInProgressSection extends ConsumerWidget {
  const _DonationInProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donationsAsync = ref.watch(inProgressDonationsProvider);

    return donationsAsync.when(
      data: (donations) {
        if (donations.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Donation in Progress'),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: donations
                    .map((r) => _DonationInProgressCard(
                          key: ValueKey(r['id'] as String? ?? ''),
                          request: r,
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _DonationInProgressCard extends StatelessWidget {
  const _DonationInProgressCard({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final requestId = request['id'] as String? ?? '';
    final bloodGroup = request['blood_group'] as String? ?? '';
    final isUrgent = request['is_urgent'] as bool? ?? false;
    final donor = request['matched_donor'] as Map<String, dynamic>?;
    final donorName = donor?['name'] as String? ?? 'Donor';
    final donorBloodGroup = donor?['blood_group'] as String? ?? '';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: () => context.pushNamed(
        RouteNames.requestDetail,
        pathParameters: {'id': requestId},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: blood type + urgency badge
          Row(
            children: [
              if (bloodGroup.isNotEmpty) BloodTypeChip(bloodType: bloodGroup),
              const SizedBox(width: 8),
              if (isUrgent)
                const UrgentRequestBadge(compact: true)
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_outlined,
                          size: 12, color: colors.secondary),
                      const SizedBox(width: 4),
                      Text(
                        'Planned',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Icon(Icons.chevron_right,
                  size: 20, color: colors.textMedium),
            ],
          ),
          const SizedBox(height: 12),

          // Matched donor info
          Row(
            children: [
              Icon(Icons.handshake_outlined,
                  size: 16, color: colors.success),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: context.textTheme.bodyMedium,
                    children: [
                      const TextSpan(text: 'Matched with '),
                      TextSpan(
                        text: donorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (donorBloodGroup.isNotEmpty)
                        TextSpan(
                          text: ' \u2022 $donorBloodGroup',
                          style: TextStyle(
                            color: colors.textMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
