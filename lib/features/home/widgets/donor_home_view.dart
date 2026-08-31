import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/request_reasons.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/reason_pill.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../features/chatbot/widgets/ask_donora_ai_card.dart';
import '../../../features/chat/providers/chat_providers.dart';
import '../../../features/requests/providers/request_detail_provider.dart';
import '../providers/home_providers.dart';

/// Donor home view — verification banner, urgent requests, cooldown status.
class DonorHomeView extends ConsumerWidget {
  const DonorHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Verification banner (if not verified) ─────────────────
          profileAsync.whenOrNull(
                data: (profile) => profile.isVerified
                    ? const SizedBox.shrink()
                    : const _VerificationBanner(),
              ) ??
              const SizedBox.shrink(),

          // ── Donation Status ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Your Donation Status',
              style: context.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _DonationStatusCard(),
          ),
          const SizedBox(height: 16),

          // ── Ask Donora AI ─────────────────────────────────────────
          const AskDonoraAiCard(),
          const SizedBox(height: 24),
          // ── Urgent Requests Near You ──────────────────────────────
          _SectionHeader(
            title: 'All Blood Requests',
            onSeeAll: () => context.pushNamed(RouteNames.map),
          ),
          const SizedBox(height: 12),
          const _UrgentRequestsList(),

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
          Expanded(child: Text(title, style: context.textTheme.titleLarge)),
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
// Verification banner
// ═══════════════════════════════════════════════════════════════════════════════

class _VerificationBanner extends ConsumerStatefulWidget {
  const _VerificationBanner();

  @override
  ConsumerState<_VerificationBanner> createState() =>
      _VerificationBannerState();
}

class _VerificationBannerState extends ConsumerState<_VerificationBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Dismissible(
        key: const ValueKey('verification_banner'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) => setState(() => _dismissed = true),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.warning, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: colors.warning,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Complete verification to start receiving requests',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Verify Now',
                onPressed: () => context.pushNamed(RouteNames.verification),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Urgent requests list (realtime)
// ═══════════════════════════════════════════════════════════════════════════════

class _UrgentRequestsList extends ConsumerWidget {
  const _UrgentRequestsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamAsync = ref.watch(urgentRequestsStreamProvider);

    return streamAsync.when(
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
                onPressed: () => ref.invalidate(urgentRequestsStreamProvider),
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
              'No active blood requests right now.',
              style: context.textTheme.bodyMedium,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: requests
                .map(
                  (r) => _UrgentRequestCard(
                    key: ValueKey(r['id'] as String? ?? ''),
                    request: r,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _UrgentRequestCard extends ConsumerStatefulWidget {
  const _UrgentRequestCard({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  ConsumerState<_UrgentRequestCard> createState() => _UrgentRequestCardState();
}

class _UrgentRequestCardState extends ConsumerState<_UrgentRequestCard> {
  bool _isResponding = false;
  bool _isOpeningChat = false;

  /// Responds via secure RPC which locks the donor and sets request to 'accepted'.
  Future<void> _onRespond() async {
    final requestId = widget.request['id'] as String? ?? '';
    final requesterId = widget.request['requester_id'] as String? ?? '';
    final bloodGroup = widget.request['blood_group'] as String? ?? '';
    final patientName =
        widget.request['patient_name'] as String? ?? 'the patient';
    if (requestId.isEmpty || requesterId.isEmpty) return;

    // Check if donor already has an active commitment.
    final hasCommitment = await ref.read(
      donorHasActiveCommitmentProvider.future,
    );
    if (!mounted) return;
    if (hasCommitment) {
      context.showSnackBar(
        'You already have an active donation commitment. Complete it first.',
        isError: true,
      );
      return;
    }

    // Show confirmation dialog.
    if (!mounted) return;
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Confirm donation',
      message:
          'Are you willing to donate $bloodGroup blood for $patientName? '
          'You will be locked to this request until the donation is confirmed.',
      icon: Icons.favorite_rounded,
      confirmLabel: "Yes, I'll donate",
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isResponding = true);
    try {
      final result = await ref
          .read(respondToRequestActionProvider)
          .call(requestId: requestId);

      if (!mounted) return;

      if (!result.success) {
        context.showSnackBar(
          result.message ?? 'Could not submit response. Please try again.',
          isError: true,
        );
        return;
      }

      // Open conversation with requester.
      final conversationId = await ref
          .read(getOrCreateConversationProvider)
          .call(requesterId);

      if (!mounted) return;
      if (conversationId != null) {
        context.pushNamed(
          RouteNames.conversation,
          pathParameters: {'id': conversationId},
        );
      }
    } catch (_) {
      if (mounted) {
        context.showSnackBar(
          'Could not submit response. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  /// Opens a direct conversation with the requester.
  Future<void> _onChat() async {
    final requesterId = widget.request['requester_id'] as String? ?? '';
    if (requesterId.isEmpty) return;

    setState(() => _isOpeningChat = true);
    try {
      final conversationId = await ref
          .read(getOrCreateConversationProvider)
          .call(requesterId);

      if (!mounted) return;
      if (conversationId != null) {
        context.pushNamed(
          RouteNames.conversation,
          pathParameters: {'id': conversationId},
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

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
    final bloodGroup = widget.request['blood_group'] as String? ?? '';
    final city = widget.request['city'] as String? ?? '';
    final patientName = widget.request['patient_name'] as String? ?? '';
    final notes = widget.request['notes'] as String? ?? '';
    final isUrgent = widget.request['is_urgent'] as bool? ?? false;
    final expiresAt = DateTime.tryParse(
      widget.request['expires_at'] as String? ?? '',
    );
    final plannedDate = DateTime.tryParse(
      widget.request['planned_date'] as String? ?? '',
    );
    final reason = RequestReason.fromValue(
      widget.request['reason'] as String?,
    );
    final requester = widget.request['requester_profiles'] as Map<String, dynamic>?;
    final rawName = requester?['name'] as String?;
    final requesterName = (rawName != null && rawName.isNotEmpty) ? rawName : 'Seeker';
    final requesterPhotoUrl = requester?['profile_photo_url'] as String?;
    final isRequesterVerified = requester?['is_verified'] == true;

    // Check commitment status for disabling the respond button.
    final hasCommitmentAsync = ref.watch(donorHasActiveCommitmentProvider);
    final hasCommitment = hasCommitmentAsync.valueOrNull ?? false;

    return Container(
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
          // ── Requester identity (most prominent) ──────────────────
          Row(
            children: [
              // Avatar circle (photo or initials)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primaryContainer,
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: (requesterPhotoUrl != null && requesterPhotoUrl.isNotEmpty)
                      ? Image.network(
                          requesterPhotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(
                              _getInitials(requesterName),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _getInitials(requesterName),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              // Name + verified badge
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        requesterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.textHigh,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (isRequesterVerified) ...[
                      const SizedBox(width: 4),
                      const VerifiedBadge(compact: true),
                    ],
                  ],
                ),
              ),
              // Blood type badge
              if (bloodGroup.isNotEmpty) BloodTypeChip(bloodType: bloodGroup),
            ],
          ),
          const SizedBox(height: 6),

          // ── Patient name (secondary) ─────────────────────────────
          if (patientName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'For: $patientName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // ── Metadata row: city · expiry/reason ───────────────────
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (city.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: colors.textMedium,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      city,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textMedium,
                      ),
                    ),
                  ],
                ),
              if (city.isNotEmpty && (isUrgent || reason.value != 'other'))
                Text(
                  '\u00b7',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textMedium.withValues(alpha: 0.5),
                  ),
                ),
              if (isUrgent && expiresAt != null)
                _DonorExpiryLabel(expiresAt: expiresAt, isUrgent: true)
              else if (!isUrgent && plannedDate != null)
                _DonorExpiryLabel(
                  expiresAt: expiresAt,
                  isUrgent: false,
                  plannedDate: plannedDate,
                ),
              if (reason.value != 'other') ReasonPill(reason: reason),
            ],
          ),

          // ── Notes ────────────────────────────────────────────────
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              notes,
              style: context.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),

          // ── Actions ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: _isResponding
                      ? 'Submitting\u2026'
                      : hasCommitment
                      ? 'Committed'
                      : 'Respond',
                  onPressed: (_isResponding || hasCommitment)
                      ? null
                      : _onRespond,
                ),
              ),
              const SizedBox(width: 8),
              _isOpeningChat
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : IconButton.outlined(
                      onPressed: _onChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 20),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Donation status card
// ═══════════════════════════════════════════════════════════════════════════════

class _DonationStatusCard extends ConsumerWidget {
  const _DonationStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cooldown = ref.watch(cooldownProvider);
    final colors = context.colors;

    if (cooldown.eligible) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: colors.success.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.success.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.volunteer_activism_rounded,
                        color: colors.success,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eligible to Donate',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textHigh,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Available to save lives',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colors.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: colors.success,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'You have no active cooldown. When urgent blood requests match your blood type, you will be notified immediately.',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.textMedium,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    // Inside cooldown — show progress ring.
    final progress = 1.0 - (cooldown.daysRemaining / cooldown.cooldownDays);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _CooldownRing(
                progress: progress,
                daysRemaining: cooldown.daysRemaining,
                totalDays: cooldown.cooldownDays,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cooldown Active',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'RESTING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.warning,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cooldown.daysRemaining} day${cooldown.daysRemaining == 1 ? '' : 's'} until next donation.',
                      style: context.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colors.textHigh,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Server-enforced ${cooldown.cooldownDays}-day cooldown for donor safety.',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.textMedium,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Cooldown progress ring
// ═══════════════════════════════════════════════════════════════════════════════

class _CooldownRing extends StatelessWidget {
  const _CooldownRing({
    required this.progress,
    required this.daysRemaining,
    required this.totalDays,
  });

  final double progress;
  final int daysRemaining;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: 72,
      height: 72,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          trackColor: colors.border,
          progressColor: colors.primary,
        ),
        child: Center(
          child: Text(
            '$daysRemaining',
            style: context.textTheme.titleLarge?.copyWith(
              color: colors.primary,
              fontSize: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 5.0;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Expiry label for donor feed cards
// ═══════════════════════════════════════════════════════════════════════════════

class _DonorExpiryLabel extends StatelessWidget {
  const _DonorExpiryLabel({
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
      final countdown = Formatters.expiresCountdown(expiresAt!);
      final isLow = expiresAt!.difference(DateTime.now()).inHours < 6;
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

    return const SizedBox.shrink();
  }
}
