import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../services/supabase/supabase_client_provider.dart';

/// Opens the donation feedback bottom sheet after a seeker confirms DONATED.
///
/// Collects a 1-5 star rating and a yes/no "Is donor appreciated?" answer,
/// then submits both via [submit_donation_feedback] RPC.
///
/// The sheet can be dismissed without submitting (feedback is optional).
/// Returns `true` when feedback was submitted successfully.
Future<bool?> showDonationFeedbackSheet(
  BuildContext context, {
  required String requestId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _DonationFeedbackSheet(requestId: requestId),
  );
}

class _DonationFeedbackSheet extends ConsumerStatefulWidget {
  const _DonationFeedbackSheet({required this.requestId});

  final String requestId;

  @override
  ConsumerState<_DonationFeedbackSheet> createState() =>
      _DonationFeedbackSheetState();
}

class _DonationFeedbackSheetState extends ConsumerState<_DonationFeedbackSheet> {
  int? _starRating;
  bool? _isAppreciated;
  bool _isSubmitting = false;

  bool get _canSubmit => _starRating != null && _isAppreciated != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Rate this donation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textHigh,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your feedback helps other seekers.',
              style: TextStyle(
                fontSize: 13,
                color: colors.textMedium,
              ),
            ),
            const SizedBox(height: 24),

            // Star rating row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final index = i + 1;
                final filled = _starRating != null && index <= _starRating!;
                return GestureDetector(
                  onTap: _isSubmitting
                      ? null
                      : () => setState(() => _starRating = index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      filled ? Icons.star : Icons.star_border,
                      size: 36,
                      color: filled ? colors.warning : colors.textMedium,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // "Is donor appreciated?" Yes / No
            Text(
              'Is donor appreciated?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textHigh,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FeedbackChoiceButton(
                    label: 'Yes',
                    icon: Icons.thumb_up_outlined,
                    isSelected: _isAppreciated == true,
                    selectedColor: colors.success,
                    onTap: _isSubmitting
                        ? null
                        : () => setState(() => _isAppreciated = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeedbackChoiceButton(
                    label: 'No',
                    icon: Icons.thumb_down_outlined,
                    isSelected: _isAppreciated == false,
                    selectedColor: colors.urgent,
                    onTap: _isSubmitting
                        ? null
                        : () => setState(() => _isAppreciated = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _canSubmit && !_isSubmitting ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: colors.border,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit feedback',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_starRating == null || _isAppreciated == null) return;
    setState(() => _isSubmitting = true);

    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc(
        'submit_donation_feedback',
        params: {
          'p_request_id': widget.requestId,
          'p_star_rating': _starRating,
          'p_is_appreciated': _isAppreciated,
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          'Could not submit feedback. Please try again.',
          isError: true,
        );
        setState(() => _isSubmitting = false);
      }
    }
  }
}

// ── Choice button ────────────────────────────────────────────────────────────

class _FeedbackChoiceButton extends StatelessWidget {
  const _FeedbackChoiceButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bgColor = isSelected
        ? selectedColor.withValues(alpha: 0.12)
        : colors.surface;
    final borderColor = isSelected
        ? selectedColor.withValues(alpha: 0.5)
        : colors.border;
    final textColor = isSelected ? selectedColor : colors.textMedium;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
