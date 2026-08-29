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
import '../../../core/widgets/urgent_request_badge.dart';
import '../../../core/widgets/verified_badge.dart';
import '../providers/request_detail_provider.dart';

/// Detail view for a single blood request, including donor responses.
///
/// Shown when a seeker taps one of their active requests.
/// Top: summary card with badges, details, edit/close actions.
/// Below: list of donors who responded, or empty "waiting" state.
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final requestAsync = ref.watch(requestDetailProvider(requestId));

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text('Request Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(RouteNames.home);
            }
          },
        ),
      ),
      body: requestAsync.when(
        data: (request) => _RequestBody(requestId: requestId, request: request),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: colors.textMedium),
                const SizedBox(height: 16),
                Text(
                  'Could not load request',
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
        ),
      ),
    );
  }
}

// ── Request body (loaded state) ───────────────────────────────────────────────

class _RequestBody extends ConsumerWidget {
  const _RequestBody({required this.requestId, required this.request});

  final String requestId;
  final RequestDetail request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _RequestSummaryCard(request: request, requestId: requestId),
        const SizedBox(height: 24),
        _ResponsesSection(requestId: requestId, isUrgent: request.isUrgent),
      ],
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _RequestSummaryCard extends ConsumerWidget {
  const _RequestSummaryCard({required this.request, required this.requestId});

  final RequestDetail request;
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: urgency badge + status ──────────────────────
          Row(
            children: [
              if (request.isUrgent) ...[
                const UrgentRequestBadge(),
                const SizedBox(width: 8),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: request.isActive
                      ? colors.success.withValues(alpha: 0.1)
                      : colors.textMedium.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  request.isActive ? 'Active' : 'Closed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        request.isActive ? colors.success : colors.textMedium,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Posted ${Formatters.timeAgo(request.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textMedium,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Blood type (large chip) ──────────────────────────────
          BloodTypeChip(bloodType: request.bloodGroup, selected: true),

          const SizedBox(height: 16),

          // ── Details rows ─────────────────────────────────────────
          _DetailRow(
            icon: Icons.location_city,
            label: 'City',
            value: request.city,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.local_hospital,
            label: 'Hospital',
            value: request.hospitalName,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.bloodtype,
            label: 'Units needed',
            value: '${request.unitsNeeded}',
          ),

          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.notes,
              label: 'Notes',
              value: request.notes!,
            ),
          ],

          const SizedBox(height: 10),
          _DetailRow(
            icon: request.allowPhoneContact ? Icons.phone : Icons.chat_bubble,
            label: 'Contact',
            value: request.allowPhoneContact
                ? 'Phone call allowed'
                : 'In-app chat only',
          ),

          // ── Expires info ─────────────────────────────────────────
          if (request.isActive) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Expires ${Formatters.dateTimeShort(request.expiresAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Actions ──────────────────────────────────────────────
          if (request.isActive) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Edit',
                    onPressed: () {
                      // TODO: navigate to edit screen (future)
                    },
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _showCloseDialog(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textMedium,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Close Request'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showCloseDialog(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close this request?'),
        content: const Text(
          'This will mark your request as closed. '
          'Donors will no longer be able to respond.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.textMedium,
            ),
            child: const Text('Close Request'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        final success =
            await ref.read(closeRequestActionProvider)(requestId);
        if (context.mounted) {
          context.showSnackBar(
            success
                ? 'Request closed successfully.'
                : 'Failed to close request. Please try again.',
            isError: !success,
          );
        }
      }
    });
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.textMedium),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: colors.textHigh,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Responses section ─────────────────────────────────────────────────────────

class _ResponsesSection extends ConsumerWidget {
  const _ResponsesSection({required this.requestId, required this.isUrgent});

  final String requestId;
  final bool isUrgent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final responsesAsync = ref.watch(requestResponsesProvider(requestId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Text(
              'Donors who responded',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textHigh,
              ),
            ),
            const SizedBox(width: 8),
            responsesAsync.when(
              data: (list) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${list.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Content
        responsesAsync.when(
          data: (responders) {
            if (responders.isEmpty) {
              return _EmptyResponsesState(isUrgent: isUrgent);
            }
            return Column(
              children: [
                for (int i = 0; i < responders.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _ResponderCard(responder: responders[i]),
                ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => AppCard(
            child: Center(
              child: Text(
                'Could not load responses',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textMedium,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Responder card ────────────────────────────────────────────────────────────

class _ResponderCard extends StatelessWidget {
  const _ResponderCard({required this.responder});

  final RequestResponder responder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Donor info row ────────────────────────────────────
          Row(
            children: [
              // Avatar placeholder
              _DonorAvatar(
                name: responder.name,
                photoUrl: responder.profilePhotoUrl,
              ),
              const SizedBox(width: 12),

              // Name + badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row with badges
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          responder.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textHigh,
                          ),
                        ),
                        if (responder.isTopDonor) _TopDonorBadge(),
                        if (responder.isVerified)
                          const VerifiedBadge(compact: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Classification chip + blood type
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DonorStatusChip(
                          classification: responder.donorClassification,
                        ),
                        BloodTypeChip(bloodType: responder.bloodGroup),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── City / distance ───────────────────────────────────
          if (responder.city.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: colors.textMedium,
                ),
                const SizedBox(width: 4),
                Text(
                  responder.city,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textMedium,
                  ),
                ),
              ],
            ),
          ],

          // ── Response message ──────────────────────────────────
          if (responder.message != null &&
              responder.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                responder.message!,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textHigh,
                  height: 1.4,
                ),
              ),
            ),
          ],

          // ── Action buttons ────────────────────────────────────
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: PrimaryButton(
                    label: 'Chat',
                    onPressed: () {
                      // TODO: navigate to chat with donor
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to donor detail
                      context.pushNamed(
                        RouteNames.donorDetail,
                        pathParameters: {'id': responder.donorId},
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textHigh,
                      side: BorderSide(color: colors.border, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('View Profile'),
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

// ── Donor avatar ──────────────────────────────────────────────────────────────

class _DonorAvatar extends StatelessWidget {
  const _DonorAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Show network image if available.
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: colors.primaryContainer,
      );
    }

    // Fallback: initial letter in a colored circle.
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.primary,
        ),
      ),
    );
  }
}

// ── Top donor badge ───────────────────────────────────────────────────────────

class _TopDonorBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          Icon(
            Icons.emoji_events,
            size: 12,
            color: Color(0xFFF9A825),
          ),
          SizedBox(width: 3),
          Text(
            'Top Donor',
            style: TextStyle(
              fontSize: 10,
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

// ── Empty responses state ─────────────────────────────────────────────────────

class _EmptyResponsesState extends StatefulWidget {
  const _EmptyResponsesState({required this.isUrgent});

  final bool isUrgent;

  @override
  State<_EmptyResponsesState> createState() => _EmptyResponsesStateState();
}

class _EmptyResponsesStateState extends State<_EmptyResponsesState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Illustration placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 36,
              color: colors.secondary,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'No responses yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textHigh,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Verified donors nearby have been notified.\nResponses will appear here as they come in.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colors.textMedium,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Pulsing dot + "Live" indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.success.withValues(
                        alpha: 0.4 + (_pulseController.value * 0.6),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isUrgent
                        ? 'Actively notifying donors'
                        : 'Waiting for responses',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.success,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
