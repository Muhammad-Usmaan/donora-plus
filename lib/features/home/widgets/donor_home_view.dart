import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/urgent_request_badge.dart';
import '../providers/home_providers.dart';

/// Donor home view — verification banner, urgent requests, cooldown status.
class DonorHomeView extends ConsumerWidget {
  const DonorHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
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

          // ── Urgent Requests Near You ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Urgent Requests Near You',
              style: context.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          const _UrgentRequestsList(),
          const SizedBox(height: 24),

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
          const SizedBox(height: 24),
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.warning, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined,
                      color: colors.warning, size: 22),
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
                onPressed: () =>
                    context.pushNamed(RouteNames.verification),
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
                onPressed: () =>
                    ref.invalidate(urgentRequestsStreamProvider),
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
              'No urgent requests in your area right now.',
              style: context.textTheme.bodyMedium,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: requests
                .map((r) => _UrgentRequestCard(request: r))
                .toList(),
          ),
        );
      },
    );
  }
}

class _UrgentRequestCard extends StatelessWidget {
  const _UrgentRequestCard({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bloodGroup = request['blood_group'] as String? ?? '';
    final city = request['city'] as String? ?? '';
    final notes = request['notes'] as String? ?? '';
    final unitsNeeded = request['units_needed'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const UrgentRequestBadge(),
              const SizedBox(width: 8),
              if (bloodGroup.isNotEmpty)
                BloodTypeChip(bloodType: bloodGroup),
              const Spacer(),
              if (unitsNeeded > 0)
                Text(
                  '$unitsNeeded unit${unitsNeeded > 1 ? 's' : ''}',
                  style: context.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // City / distance
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 14, color: colors.textMedium),
              const SizedBox(width: 4),
              Text(city, style: context.textTheme.bodyMedium),
            ],
          ),

          // Notes
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              notes,
              style: context.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Respond',
                  onPressed: () {
                    // TODO: Navigate to respond flow.
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: () =>
                    context.pushNamed(RouteNames.chat),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: colors.success, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eligible to donate',
                    style: context.textTheme.titleMedium?.copyWith(
                      color: colors.success,
                    ),
                  ),
                  Text(
                    'You are ready to help someone today.',
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Inside cooldown — show progress ring.
    final progress =
        1.0 - (cooldown.daysRemaining / cooldown.cooldownDays);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
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
                Text(
                  'Cooldown active',
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${cooldown.daysRemaining} day${cooldown.daysRemaining == 1 ? '' : 's'} until you can donate again.',
                  style: context.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Server-enforced ${cooldown.cooldownDays}-day cooldown.',
                  style: context.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
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
