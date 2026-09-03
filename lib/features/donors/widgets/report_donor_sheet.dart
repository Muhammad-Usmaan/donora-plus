import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/donor_report_provider.dart';

/// Opens the "Report Donor" bottom sheet.
///
/// The sheet collects a reason (max 300 chars) and inserts a row into
/// `donor_reports`. On success, pops the sheet and shows a confirmation
/// snackbar. Handles duplicate-pending and generic errors gracefully.
void showReportDonorSheet(
  BuildContext context, {
  required String donorId,
  required String donorName,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReportDonorSheet(donorId: donorId, donorName: donorName),
  );
}

class _ReportDonorSheet extends ConsumerStatefulWidget {
  const _ReportDonorSheet({required this.donorId, required this.donorName});

  final String donorId;
  final String donorName;

  @override
  ConsumerState<_ReportDonorSheet> createState() => _ReportDonorSheetState();
}

class _ReportDonorSheetState extends ConsumerState<_ReportDonorSheet> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  static const int _maxLength = 300;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
          const SizedBox(height: 16),

          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.urgent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: PhosphorIcon(
              PhosphorIconsRegular.flag,
              size: 26,
              color: colors.urgent,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Report this profile?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textHigh,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            'Let our moderation team know if something looks wrong — '
            'false information or unsafe behavior. Your report is '
            'confidential.',
            style: TextStyle(
              fontSize: 13.5,
              color: colors.textMedium,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Reason field
          TextField(
            controller: _controller,
            maxLength: _maxLength,
            maxLines: 4,
            minLines: 3,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              hintText: 'Describe the issue…',
              hintStyle: TextStyle(color: colors.textMedium, fontSize: 14),
              counterText: '',
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Text(
                '${_controller.text.length}/$_maxLength',
                style: TextStyle(fontSize: 12, color: colors.textMedium),
              ),
            ),
          ),

          // Submit button
          PrimaryButton(
            label: 'Submit Report',
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 8),

          // Cancel
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textMedium),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      context.showSnackBar('Please describe the issue before submitting.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await submitDonorReport(
        ref: ref,
        reportedUserId: widget.donorId,
        reason: reason,
      );

      if (!mounted) return;

      switch (result) {
        case DonorReportResult.success:
          Navigator.of(context).pop();
          context.showSnackBar(
            'Thanks — our team will review this profile.',
          );
        case DonorReportResult.duplicatePending:
          context.showSnackBar(
            "You've already reported this user. "
            'Our team will review your previous report.',
            isError: true,
          );
        case DonorReportResult.error:
          context.showSnackBar(
            'Could not submit the report. Please try again.',
            isError: true,
          );
      }
    } catch (e) {
      // Catch-all: ensures _isSubmitting is always reset even if
      // submitDonorReport throws an unexpected exception.
      if (!mounted) return;
      context.showSnackBar(
        'Could not submit the report. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
