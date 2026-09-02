import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/map_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/blood_type_chip.dart';
import '../../../core/widgets/donor_status_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/reason_pill.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/urgent_request_badge.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../chat/providers/chat_providers.dart';
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
    final currentUser = ref.watch(currentUserProvider);
    final isRequester = currentUser?.id == request.requesterId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _RequestSummaryCard(
          request: request,
          requestId: requestId,
          isRequester: isRequester,
        ),
        const SizedBox(height: 24),
        // Show confirmation card when request is accepted and current user is requester
        if (isRequester && request.isAccepted) ...[
          _DonationConfirmationCard(
            requestId: requestId,
            requestDetail: request,
          ),
          const SizedBox(height: 24),
        ],
        _ResponsesSection(
          requestId: requestId,
          isUrgent: request.isUrgent,
          isRequester: isRequester,
        ),
      ],
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _RequestSummaryCard extends ConsumerWidget {
  const _RequestSummaryCard({
    required this.request,
    required this.requestId,
    required this.isRequester,
  });

  final RequestDetail request;
  final String requestId;
  final bool isRequester;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      request.status == 'expired' ||
                          (request.status == 'active' && request.isExpired)
                      ? colors.warning.withValues(alpha: 0.1)
                      : request.isActive
                      ? colors.success.withValues(alpha: 0.1)
                      : colors.textMedium.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  request.status == 'expired' ||
                          (request.status == 'active' && request.isExpired)
                      ? 'Expired'
                      : request.isActive
                      ? 'Active'
                      : 'Closed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        request.status == 'expired' ||
                            (request.status == 'active' && request.isExpired)
                        ? colors.warning
                        : request.isActive
                        ? colors.success
                        : colors.textMedium,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Posted ${Formatters.timeAgo(request.createdAt)}',
                style: TextStyle(fontSize: 12, color: colors.textMedium),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Blood type (large chip) ──────────────────────────────
          BloodTypeChip(bloodType: request.bloodGroup, selected: true),

          const SizedBox(height: 12),

          // ── Reason pill (+ free-text note for "other") ─
          ReasonPill(reason: request.reason),
          if (request.reasonNote != null && request.reasonNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.reasonNote!,
              style: TextStyle(fontSize: 13, color: colors.textMedium),
            ),
          ],

          const SizedBox(height: 16),

          // ── Requester + Patient info ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: colors.textMedium,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Requested by  ',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textMedium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        request.requesterName,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textHigh,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (request.requesterIsVerified)
                      const VerifiedBadge(compact: true),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 14,
                      color: colors.textMedium,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Patient: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textMedium,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      request.patientName,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textHigh,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Details rows ─────────────────────────────────────────
          GestureDetector(
            onTap: () {
              if (request.latitude != null && request.longitude != null) {
                MapUtils.openPlaceMarker(
                  request.latitude!,
                  request.longitude!,
                  label: request.city,
                );
              } else {
                MapUtils.openNavigationByName(request.city);
              }
            },
            child: _DetailRow(
              icon: Icons.location_city,
              label: 'City',
              value: request.city,
              tappable: true,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              if (request.latitude != null && request.longitude != null) {
                MapUtils.openPlaceMarker(
                  request.latitude!,
                  request.longitude!,
                  label: request.hospitalName.isNotEmpty
                      ? request.hospitalName
                      : request.city,
                );
              } else {
                MapUtils.openNavigationByName(
                  '${request.hospitalName}, ${request.city}',
                );
              }
            },
            child: _DetailRow(
              icon: Icons.local_hospital,
              label: 'Hospital',
              value: request.hospitalName,
              tappable: true,
            ),
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
                color: request.isUrgent
                    ? colors.primaryContainer
                    : colors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    request.isUrgent ? Icons.schedule : Icons.event_outlined,
                    size: 16,
                    color: request.isUrgent ? colors.primary : colors.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.isUrgent
                          ? Formatters.expiresCountdown(request.expiresAt)
                          : request.plannedDate != null
                          ? '${Formatters.neededBy(request.plannedDate!)}  •  Expires ${Formatters.dateTimeShort(request.expiresAt)}'
                          : 'Expires ${Formatters.dateTimeShort(request.expiresAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: request.isUrgent
                            ? colors.primary
                            : colors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Actions (only for the requester) ──────────────────────
          if (isRequester && request.isActive) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Edit',
                    onPressed: () {
                      context.pushNamed(
                        RouteNames.requestCreate,
                        extra: request,
                        queryParameters: {'editId': request.id},
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _showCloseDialog(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textMedium,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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

  void _showCloseDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Close this request?',
      message:
          'This will mark your request as closed. '
          'Donors will no longer be able to respond.',
      confirmLabel: 'Close Request',
      cancelLabel: 'Cancel',
      destructive: true,
    );

    if (confirmed == true && context.mounted) {
      final success = await ref.read(closeRequestActionProvider)(requestId);
      if (context.mounted) {
        context.showSnackBar(
          success
              ? 'Request closed successfully.'
              : 'Failed to close request. Please try again.',
          isError: !success,
        );
      }
    }
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.tappable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: tappable ? colors.primary : colors.textMedium,
        ),
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
                  color: tappable ? colors.primary : colors.textHigh,
                  fontWeight: FontWeight.w500,
                  decoration: tappable ? TextDecoration.underline : null,
                ),
              ),
            ],
          ),
        ),
        if (tappable) Icon(Icons.open_in_new, size: 14, color: colors.primary),
      ],
    );
  }
}

// ── Donation confirmation card (for requester when request is accepted) ──────

class _DonationConfirmationCard extends ConsumerStatefulWidget {
  const _DonationConfirmationCard({
    required this.requestId,
    required this.requestDetail,
  });

  final String requestId;
  final RequestDetail requestDetail;

  @override
  ConsumerState<_DonationConfirmationCard> createState() =>
      _DonationConfirmationCardState();
}

class _DonationConfirmationCardState
    extends ConsumerState<_DonationConfirmationCard> {
  bool _isLoading = false;

  Future<void> _confirm(bool confirmed) async {
    setState(() => _isLoading = true);
    final result = await ref
        .read(confirmDonationActionProvider)
        .call(requestId: widget.requestId, confirmed: confirmed);
    if (mounted) {
      setState(() => _isLoading = false);
      context.showSnackBar(
        result.message ??
            (confirmed ? 'Donation confirmed!' : 'Match cancelled.'),
        isError: !result.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.08),
            colors.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volunteer_activism, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Donation in progress',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A donor has committed to donate for this request. Has the blood been donated?',
            style: TextStyle(
              fontSize: 13,
              color: colors.textMedium,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () => _confirm(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Yes, donated',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () => _confirm(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.urgent,
                        side: BorderSide(
                          color: colors.urgent.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancelled',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

// ── Responses section ─────────────────────────────────────────────────────────

class _ResponsesSection extends ConsumerWidget {
  const _ResponsesSection({
    required this.requestId,
    required this.isUrgent,
    required this.isRequester,
  });

  final String requestId;
  final bool isUrgent;
  final bool isRequester;

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  _ResponderCard(
                    key: ValueKey(responders[i].donorId),
                    responder: responders[i],
                    isRequester: isRequester,
                  ),
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
                style: TextStyle(fontSize: 14, color: colors.textMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Responder card ────────────────────────────────────────────────────────────

class _ResponderCard extends ConsumerStatefulWidget {
  const _ResponderCard({
    super.key,
    required this.responder,
    required this.isRequester,
  });

  final RequestResponder responder;
  final bool isRequester;

  @override
  ConsumerState<_ResponderCard> createState() => _ResponderCardState();
}

class _ResponderCardState extends ConsumerState<_ResponderCard> {
  bool _chatLoading = false;

  Future<void> _openChat() async {
    setState(() => _chatLoading = true);
    final conversationId = await ref
        .read(getOrCreateConversationProvider)
        .call(widget.responder.donorId);
    if (!mounted) return;
    setState(() => _chatLoading = false);
    if (conversationId == null) {
      context.showSnackBar('Could not open chat. Try again.', isError: true);
      return;
    }
    context.pushNamed(
      RouteNames.conversation,
      pathParameters: {'id': conversationId},
      queryParameters: {
        'name': widget.responder.name,
        if (widget.responder.profilePhotoUrl != null &&
            widget.responder.profilePhotoUrl!.isNotEmpty)
          'photo': widget.responder.profilePhotoUrl!,
        if (widget.responder.isVerified) 'verified': '1',
      },
    );
  }

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
              _DonorAvatar(
                name: widget.responder.name,
                photoUrl: widget.responder.profilePhotoUrl,
              ),
              const SizedBox(width: 12),

              // Name + badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          widget.responder.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textHigh,
                          ),
                        ),
                        if (widget.responder.isTopDonor) _TopDonorBadge(),
                        if (widget.responder.isVerified)
                          const VerifiedBadge(compact: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DonorStatusChip(
                          classification: widget.responder.donorClassification,
                        ),
                        BloodTypeChip(bloodType: widget.responder.bloodGroup),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── City ───────────────────────────────────────────────
          if (widget.responder.city.isNotEmpty) ...[
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
                  widget.responder.city,
                  style: TextStyle(fontSize: 13, color: colors.textMedium),
                ),
              ],
            ),
          ],

          // ── Response message ──────────────────────────────────
          if (widget.responder.message != null &&
              widget.responder.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.responder.message!,
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
                  child: _chatLoading
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : PrimaryButton(label: 'Chat', onPressed: _openChat),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () {
                      context.pushNamed(
                        RouteNames.donorDetail,
                        pathParameters: {'id': widget.responder.donorId},
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
          Icon(Icons.emoji_events, size: 12, color: Color(0xFFF9A825)),
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
