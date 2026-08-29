import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/donor_status_chip.dart';
import '../../../core/widgets/verified_badge.dart';
import '../providers/donors_list_provider.dart';

/// Donor list screen — browse, search, and filter donors.
///
/// Search text, blood-type chips, and the verified-only toggle all filter
/// the cached donor list client-side (see [filteredDonorsProvider]) so
/// typing never triggers a refetch.
class DonorsScreen extends ConsumerStatefulWidget {
  const DonorsScreen({super.key});

  @override
  ConsumerState<DonorsScreen> createState() => _DonorsScreenState();
}

class _DonorsScreenState extends ConsumerState<DonorsScreen> {
  final _searchCtrl = TextEditingController();
  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    ref.read(donorListFilterProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final donorsAsync = ref.watch(donorsListProvider);
    final filter = ref.watch(donorListFilterProvider);
    final donors = ref.watch(filteredDonorsProvider);

    final hasActiveFilters = filter.query.trim().isNotEmpty ||
        filter.isFilteringBlood ||
        filter.verifiedOnly;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text('Find Donors'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // ── Search ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) =>
                  ref.read(donorListFilterProvider.notifier).setQuery(value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name or city',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: filter.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchCtrl.clear();
                          ref
                              .read(donorListFilterProvider.notifier)
                              .setQuery('');
                        },
                      ),
              ),
            ),
          ),

          // ── Blood type + verified filters ──────────────────────
          SizedBox(
            height: 44,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final type in _bloodTypes) ...[
                    BloodTypeChip(
                      bloodType: type,
                      selected: filter.selectedBloodTypes.contains(type),
                      onTap: () => ref
                          .read(donorListFilterProvider.notifier)
                          .toggleBloodType(type),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _VerifiedOnlyPill(
                    selected: filter.verifiedOnly,
                    onTap: () => ref
                        .read(donorListFilterProvider.notifier)
                        .setVerifiedOnly(!filter.verifiedOnly),
                  ),
                ],
              ),
            ),
          ),

          // ── Result count + clear ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    donorsAsync.hasValue
                        ? '${donors.length} donor${donors.length == 1 ? '' : 's'}'
                        : ' ',
                    style: context.textTheme.bodySmall
                        ?.copyWith(color: colors.textMedium),
                  ),
                ),
                if (hasActiveFilters)
                  TextButton.icon(
                    onPressed: _clearFilters,
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

          // ── List ───────────────────────────────────────────────
          Expanded(
            child: donorsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(donorsListProvider),
              ),
              data: (allDonors) {
                if (allDonors.isEmpty) {
                  return const _EmptyView(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'No donors yet',
                    message:
                        'Donors will appear here as they join Donora+.',
                  );
                }
                if (donors.isEmpty) {
                  return _EmptyView(
                    icon: Icons.search_off,
                    title: 'No donors match your filters',
                    message:
                        'Try a different name, city, or blood type.',
                    actionLabel: 'Clear filters',
                    onAction: _clearFilters,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: donors.length,
                  itemBuilder: (context, index) => _DonorCard(
                    donor: donors[index],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Verified-only filter pill ─────────────────────────────────────────────────

class _VerifiedOnlyPill extends StatelessWidget {
  const _VerifiedOnlyPill({required this.selected, required this.onTap});

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
          color: selected ? colors.secondary : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_outlined,
              size: 16,
              color: selected ? Colors.white : colors.secondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Verified only',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : colors.secondary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Donor card ────────────────────────────────────────────────────────────────

class _DonorCard extends StatelessWidget {
  const _DonorCard({required this.donor});

  final DonorListItem donor;

  String get _initials {
    final words = donor.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2);
    if (words.isEmpty) return '?';
    return words.map((word) => word[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasPhoto =
        donor.profilePhotoUrl != null && donor.profilePhotoUrl!.isNotEmpty;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.pushNamed(
        RouteNames.donorDetail,
        pathParameters: {'id': donor.id},
      ),
      child: Row(
        children: [
          // Avatar — photo if available, otherwise initials.
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.primaryContainer,
            backgroundImage: hasPhoto
                ? NetworkImage(donor.profilePhotoUrl!)
                : null,
            child: hasPhoto
                ? null
                : Text(
                    _initials,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Name, badges, city, classification.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        donor.name,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (donor.isVerified) ...[
                      const SizedBox(width: 6),
                      const VerifiedBadge(compact: true),
                    ],
                    if (donor.isTopDonor) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.star, size: 16, color: colors.warning),
                    ],
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
                        donor.city.isEmpty ? 'Location not set' : donor.city,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall
                            ?.copyWith(color: colors.textMedium),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DonorStatusChip(classification: donor.donorClassification),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Blood type + navigation affordance.
          if (donor.bloodGroup.isNotEmpty) ...[
            BloodTypeChip(bloodType: donor.bloodGroup),
          ],
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: colors.textMedium,
          ),
        ],
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
              style: context.textTheme.bodySmall
                  ?.copyWith(color: colors.textMedium),
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
              'Could not load donors',
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall
                  ?.copyWith(color: colors.textMedium),
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
