import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/donor_status_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/verified_badge.dart';
import '../providers/donor_detail_provider.dart';

/// Public-facing detail view for a single donor.
///
/// Opened from map markers, donor lists, or request responses.
/// Displays profile header, info cards, and a sticky action bar.
/// CNIC images and raw verification documents are NEVER shown here —
/// this is the public profile; verification docs are admin-only.
class DonorDetailScreen extends ConsumerWidget {
  const DonorDetailScreen({super.key, required this.donorId});

  final String donorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final donorAsync = ref.watch(donorDetailProvider(donorId));

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text('Donor Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: donorAsync.when(
        data: (donor) => _DonorDetailBody(donorId: donorId, donor: donor),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(error: error),
      ),
    );
  }
}

// ── Loaded body ───────────────────────────────────────────────────────────────

class _DonorDetailBody extends ConsumerWidget {
  const _DonorDetailBody({required this.donorId, required this.donor});

  final String donorId;
  final DonorProfile donor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responseAsync = ref.watch(donorResponseToViewerProvider(donorId));

    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _ProfileHeader(donor: donor),
              const SizedBox(height: 20),
              _InfoCard(donor: donor),
              if (donor.bio != null && donor.bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _BioCard(bio: donor.bio!),
              ],
              // Extra bottom padding so content isn't hidden by action bar.
              const SizedBox(height: 100),
            ],
          ),
        ),

        // Sticky action bar at the bottom
        _StickyActionBar(
          donorId: donorId,
          responseRequestId: responseAsync.whenOrNull(data: (id) => id),
        ),
      ],
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.donor});

  final DonorProfile donor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        // Large circular avatar
        _LargeAvatar(
          name: donor.name,
          photoUrl: donor.profilePhotoUrl,
          isVerified: donor.isVerified,
        ),
        const SizedBox(height: 16),

        // Name
        Text(
          donor.name,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colors.textHigh,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Badges row
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (donor.isVerified) const VerifiedBadge(),
            DonorStatusChip(classification: donor.donorClassification),
            if (donor.isTopDonor) const _TopDonorBadge(),
          ],
        ),
        const SizedBox(height: 12),

        // Blood type chip
        BloodTypeChip(bloodType: donor.bloodGroup, selected: true),

        // City
        if (donor.city.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: colors.textMedium),
              const SizedBox(width: 4),
              Text(
                donor.city,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Large avatar ──────────────────────────────────────────────────────────────

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({
    required this.name,
    required this.isVerified,
    this.photoUrl,
  });

  final String name;
  final bool isVerified;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Outer container with verified/unverified border.
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isVerified ? colors.success : colors.border,
          width: 2.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? CircleAvatar(
                radius: 48,
                backgroundImage: NetworkImage(photoUrl!),
                backgroundColor: colors.primaryContainer,
              )
            : CircleAvatar(
                radius: 48,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.donor});

  final DonorProfile donor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Donor Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textHigh,
            ),
          ),
          const SizedBox(height: 16),

          // Blood type
          _InfoRow(
            icon: Icons.bloodtype,
            label: 'Blood Type',
            child: BloodTypeChip(bloodType: donor.bloodGroup),
          ),

          const Divider(height: 24),

          // Total donations
          _InfoRow(
            icon: Icons.favorite_outline,
            label: 'Total Donations',
            child: Text(
              donor.totalDonations != null
                  ? '${donor.totalDonations}'
                  : '—',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textHigh,
              ),
            ),
          ),

          // Last donation date (only if the donor opted to make it public).
          if (donor.showLastDonationDate && donor.lastDonationDate != null) ...[
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Last Donation',
              child: Text(
                Formatters.dateShort(donor.lastDonationDate!),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.textHigh,
                ),
              ),
            ),
          ],

          // City
          if (donor.city.isNotEmpty) ...[
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.location_city,
              label: 'City',
              child: Text(
                donor.city,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.textHigh,
                ),
              ),
            ),
          ],

          // Classification
          const Divider(height: 24),
          _InfoRow(
            icon: Icons.people_outline,
            label: 'Classification',
            child: DonorStatusChip(
              classification: donor.donorClassification,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Icon(icon, size: 20, color: colors.textMedium),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: colors.textMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Flexible(
          flex: 0,
          child: child,
        ),
      ],
    );
  }
}

// ── Bio card ──────────────────────────────────────────────────────────────────

class _BioCard extends StatelessWidget {
  const _BioCard({required this.bio});

  final String bio;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes, size: 20, color: colors.textMedium),
              const SizedBox(width: 8),
              Text(
                'About',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textHigh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bio,
            style: TextStyle(
              fontSize: 14,
              color: colors.textHigh,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sticky action bar ─────────────────────────────────────────────────────────

class _StickyActionBar extends StatelessWidget {
  const _StickyActionBar({
    required this.donorId,
    this.responseRequestId,
  });

  final String donorId;
  final String? responseRequestId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasResponse = responseRequestId != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Message button — always shown.
          Expanded(
            flex: hasResponse ? 1 : 2,
            child: PrimaryButton(
              label: 'Message',
              icon: Icons.chat_bubble_outline,
              onPressed: () {
                // TODO: navigate to chat with this donor.
              },
            ),
          ),

          // "View Response" — only if donor responded to viewer's request.
          if (hasResponse) ...[
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                label: 'View Response',
                onPressed: () {
                  context.pushNamed(
                    RouteNames.requestDetail,
                    pathParameters: {'id': responseRequestId!},
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Top donor badge ───────────────────────────────────────────────────────────

class _TopDonorBadge extends StatelessWidget {
  const _TopDonorBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFF9A825).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 14, color: Color(0xFFF9A825)),
          SizedBox(width: 4),
          Text(
            'Top Donor',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB8860B),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 48, color: colors.textMedium),
            const SizedBox(height: 16),
            Text(
              'Could not load donor profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textHigh,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.textMedium),
            ),
          ],
        ),
      ),
    );
  }
}
