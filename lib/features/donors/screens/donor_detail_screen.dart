import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/donor_status_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../chat/providers/chat_providers.dart';
import '../providers/donor_detail_provider.dart';
import '../widgets/report_donor_sheet.dart';

// ── Layout metrics ────────────────────────────────────────────────────────────

/// Depth of the primary header below the toolbar. The avatar sits centered
/// on the seam between this block and the body content.
const double _headerDepth = 72;

/// Radius of the avatar that overlaps the header/body seam.
const double _avatarRadius = 46;

/// Total height of the primary header block (status bar + toolbar + depth).
double _headerHeight(BuildContext context) =>
    MediaQuery.of(context).padding.top + kToolbarHeight + _headerDepth;

/// Masks a phone number for the public contact line,
/// e.g. `+923001234567` → `+92 ••• ••• 567`.
String _maskPhone(String phone) {
  if (phone.length <= 6) return '••••••';
  return '${phone.substring(0, 3)} ••• ••• ${phone.substring(phone.length - 3)}';
}

/// Public-facing donor profile — the seeker's view of a donor.
///
/// Opened from map markers, donor lists, or request responses.
/// Layout: primary header with a circular back button, avatar overlapping
/// the header/body seam, name + masked contact line, Call Now / Request
/// actions, a 3-tile stats row, and plain list rows (availability, report,
/// get help). Editing and log out live on the viewer's own profile screen —
/// never here.
/// CNIC images and raw verification documents are NEVER shown here —
/// this is the public profile; verification docs are admin-only.
class DonorDetailScreen extends ConsumerWidget {
  const DonorDetailScreen({super.key, required this.donorId});

  final String donorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final donorAsync = ref.watch(donorDetailProvider(donorId));
    final headerHeight = _headerHeight(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: Stack(
          children: [
            Column(
              children: [
                _DonorHeader(
                  height: headerHeight,
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.goNamed(RouteNames.home);
                    }
                  },
                ),
                Expanded(
                  child: donorAsync.when(
                    data: (donor) =>
                        _DonorDetailBody(donorId: donorId, donor: donor),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _ErrorState(error: error),
                  ),
                ),
              ],
            ),

            // Avatar pinned on the header/body seam once the profile loads.
            donorAsync.maybeWhen(
              data: (donor) => Positioned(
                top: headerHeight - _avatarRadius,
                left: 0,
                right: 0,
                child: Center(
                  child: _SeamAvatar(
                    name: donor.name,
                    photoUrl: donor.profilePhotoUrl,
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Primary header ────────────────────────────────────────────────────────────

class _DonorHeader extends StatelessWidget {
  const _DonorHeader({required this.height, required this.onBack});

  final double height;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: context.colors.primary,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              const SizedBox(width: 12),
              _BackButton(onPressed: onBack),
              const Expanded(
                child: Center(
                  child: Text(
                    'Donor Profile',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Balances the leading back button so the title stays centered.
              const SizedBox(width: 52),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: PhosphorIcon(
              PhosphorIconsRegular.caretLeft,
              size: 22,
              color: context.colors.textHigh,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Avatar on the header/body seam ────────────────────────────────────────────

class _SeamAvatar extends StatelessWidget {
  const _SeamAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    // Contrasting white ring so the avatar reads against both the primary
    // header above the seam and the surface background below it.
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.card,
        boxShadow: [
          BoxShadow(
            color: colors.textHigh.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CircleAvatar(
          radius: _avatarRadius - 4,
          backgroundColor: colors.primaryContainer,
          backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
          child: hasPhoto
              ? null
              : Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Loaded body ───────────────────────────────────────────────────────────────

class _DonorDetailBody extends ConsumerStatefulWidget {
  const _DonorDetailBody({required this.donorId, required this.donor});

  final String donorId;
  final DonorProfile donor;

  @override
  ConsumerState<_DonorDetailBody> createState() => _DonorDetailBodyState();
}

class _DonorDetailBodyState extends ConsumerState<_DonorDetailBody> {
  bool _isRequesting = false;

  DonorProfile get _donor => widget.donor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final responseRequestId = ref
        .watch(donorResponseToViewerProvider(widget.donorId))
        .whenOrNull(data: (id) => id);
    final responseCount = ref
        .watch(donorResponseCountProvider(widget.donorId))
        .whenOrNull(data: (count) => '$count');

    final hasPhone = _donor.phone != null && _donor.phone!.isNotEmpty;
    final hasEmail = _donor.email != null && _donor.email!.isNotEmpty;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        _avatarRadius + 24,
        16,
        MediaQuery.of(context).padding.bottom + 32,
      ),
      children: [
        // Name
        Text(
          _donor.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: colors.textHigh,
          ),
        ),
        const SizedBox(height: 8),

        // Badges
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_donor.isVerified) const VerifiedBadge(),
            DonorStatusChip(classification: _donor.donorClassification),
            if (_donor.isTopDonor) const _TopDonorBadge(),
          ],
        ),

        // City + masked contact line
        if (_donor.city.isNotEmpty || hasPhone || hasEmail) ...[
          const SizedBox(height: 10),
          _ContactLines(donor: _donor, hasPhone: hasPhone),
        ],

        const SizedBox(height: 20),

        // Call Now (only when contact is on file) + Request
        Row(
          children: [
            if (hasPhone) ...[
              Expanded(
                child: PrimaryButton(
                  label: 'Call Now',
                  icon: PhosphorIconsRegular.phone,
                  onPressed: _callDonor,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: SecondaryButton(
                label: 'Request',
                isLoading: _isRequesting,
                onPressed: _isRequesting ? null : _requestDonor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Stats row — adapts layout when hemoglobin is present.
        if (_donor.hemoglobinLevel != null) ...[
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: _donor.bloodGroup,
                  caption: 'Blood Type',
                  valueColor: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: '${_donor.totalDonations ?? 0}',
                  caption: 'Donated',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: responseCount ?? '—',
                  caption: 'Requested',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: _donor.hemoglobinLevel!.toStringAsFixed(1),
                  caption: 'Hemoglobin (g/dL)',
                ),
              ),
            ],
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: _donor.bloodGroup,
                  caption: 'Blood Type',
                  valueColor: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: '${_donor.totalDonations ?? 0}',
                  caption: 'Donated',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: responseCount ?? '—',
                  caption: 'Requested',
                ),
              ),
            ],
          ),

        // Appreciation stats — visible when the donor has any donations.
        if ((_donor.totalDonations ?? 0) > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _donor.totalFeedbackCount > 0
                ? Row(
                    children: [
                      Icon(Icons.star, size: 16, color: colors.warning),
                      const SizedBox(width: 4),
                      Text(
                        _donor.averageStarRating?.toStringAsFixed(1) ?? '—',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textHigh,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_donor.appreciatedCount}/${_donor.totalFeedbackCount} appreciated',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textMedium,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'No feedback yet',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: colors.textMedium,
                    ),
                  ),
          ),
        ],

        // Last donation (only when the donor made it public)
        if (_donor.showLastDonationDate && _donor.lastDonationDate != null) ...[
          const SizedBox(height: 10),
          Text(
            'Last donation ${Formatters.dateShort(_donor.lastDonationDate!)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.textMedium),
          ),
        ],

        // Contextual: this donor responded to one of the viewer's requests.
        if (responseRequestId != null) ...[
          const SizedBox(height: 20),
          _ResponseLinkCard(requestId: responseRequestId),
        ],

        // Bio
        if (_donor.bio != null && _donor.bio!.isNotEmpty) ...[
          const SizedBox(height: 20),
          _BioCard(bio: _donor.bio!),
        ],

        const SizedBox(height: 20),

        // Plain rows: availability / report / get help
        _ListSection(donor: _donor),
      ],
    );
  }

  Future<void> _callDonor() async {
    final phone = _donor.phone;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        context.showSnackBar('No phone number available for this donor.', isError: true);
      }
      return;
    }

    final uri = Uri.parse('tel:$phone');
    try {
      if (!await launchUrl(uri)) {
        if (mounted) {
          context.showSnackBar('No dialer app available to place the call.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('No dialer app available to place the call.', isError: true);
      }
    }
  }

  /// Sends a direct request/ping: opens (or creates) the 1:1 conversation
  /// with this donor.
  Future<void> _requestDonor() async {
    setState(() => _isRequesting = true);

    final conversationId =
        await ref.read(getOrCreateConversationProvider)(widget.donorId);

    if (!mounted) return;
    setState(() => _isRequesting = false);

    if (conversationId != null) {
      context.pushNamed(
        RouteNames.conversation,
        pathParameters: {'id': conversationId},
        queryParameters: {
          'name': _donor.name,
          if (_donor.profilePhotoUrl != null &&
              _donor.profilePhotoUrl!.isNotEmpty)
            'photo': _donor.profilePhotoUrl!,
          if (_donor.isVerified) 'verified': '1',
        },
      );
    } else {
      context.showSnackBar(
        'Could not start the conversation. Please try again.',
        isError: true,
      );
    }
  }
}

// ── Contact lines ─────────────────────────────────────────────────────────────

class _ContactLines extends StatelessWidget {
  const _ContactLines({required this.donor, required this.hasPhone});

  final DonorProfile donor;
  final bool hasPhone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: colors.textMedium,
    );

    return Column(
      children: [
        if (donor.city.isNotEmpty)
          GestureDetector(
            onTap: () {
              if (donor.latitude != null && donor.longitude != null) {
                MapUtils.openPlaceMarker(
                  donor.latitude!,
                  donor.longitude!,
                  label: donor.city,
                );
              } else {
                MapUtils.openNavigationByName(donor.city);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.mapPin,
                  size: 14,
                  color: colors.textMedium,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    donor.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted.copyWith(decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.open_in_new, size: 12, color: colors.textMedium),
              ],
            ),
          ),
        if (hasPhone) ...[
          if (donor.city.isNotEmpty) const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIconsRegular.phone,
                size: 14,
                color: colors.textMedium,
              ),
              const SizedBox(width: 4),
              Text(_maskPhone(donor.phone!), style: muted),
            ],
          ),
        ] else if (donor.email != null && donor.email!.isNotEmpty) ...[
          if (donor.city.isNotEmpty) const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIconsRegular.envelope,
                size: 14,
                color: colors.textMedium,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  donor.email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Response link card ────────────────────────────────────────────────────────

/// Slim banner shown when this donor responded to one of the viewer's
/// active requests — jumps straight to that request.
class _ResponseLinkCard extends StatelessWidget {
  const _ResponseLinkCard({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          RouteNames.requestDetail,
          pathParameters: {'id': requestId},
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              PhosphorIcon(
                PhosphorIconsRegular.sealCheck,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Responded to your active request',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                size: 16,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── List section ──────────────────────────────────────────────────────────────

/// Plain rows: read-only availability, report/flag, get help.
class _ListSection extends StatelessWidget {
  const _ListSection({required this.donor});

  final DonorProfile donor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Column(
        children: [
          _ListRow(
            icon: PhosphorIconsRegular.drop,
            label: 'Available for donate',
            trailing: _AvailabilityChip(available: donor.isAvailableToDonate),
          ),
          Divider(height: 1, color: context.colors.border),
          _ListRow(
            icon: PhosphorIconsRegular.flag,
            label: 'Report / Flag profile',
            onTap: () => _showReportDialog(context),
          ),
          Divider(height: 1, color: context.colors.border),
          _ListRow(
            icon: PhosphorIconsRegular.lifebuoy,
            label: 'Get help',
            onTap: () => context.pushNamed(RouteNames.helpFaq),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showReportDonorSheet(context, donorId: donor.id, donorName: donor.name);
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
  });

  final PhosphorIconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final row = Row(
      children: [
        PhosphorIcon(icon, size: 20, color: colors.textMedium),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textHigh,
            ),
          ),
        ),
        trailing ??
            PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              size: 18,
              color: colors.textMedium,
            ),
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: row,
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: row,
      ),
    );
  }
}

// ── Availability chip ─────────────────────────────────────────────────────────

/// Read-only status chip — "Available" (green) / "Not available" (gray).
/// The availability toggle only exists on the donor's own profile.
class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = available ? colors.success : colors.textMedium;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            available
                ? PhosphorIconsRegular.checkCircle
                : PhosphorIconsRegular.xCircle,
            size: 14,
            color: accent,
          ),
          const SizedBox(width: 4),
          Text(
            available ? 'Available' : 'Not available',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
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
            PhosphorIcon(
              PhosphorIconsRegular.userCircle,
              size: 48,
              color: colors.textMedium,
            ),
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
