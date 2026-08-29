import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/extensions.dart';

/// Donora+ styled dialog.
///
/// Features compared to a plain [AlertDialog]:
/// - Optional leading icon inside a tinted circle (matches the design system).
/// - Title + optional supporting message with consistent typography.
/// - Content area for forms, kept visually separated from the header.
/// - Action row with a filled primary button and a quiet dismiss button.
///
/// Use [showAppDialog] to display it, or pass it to `showDialog` directly.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.iconColor,
    this.content,
    this.actions = const <Widget>[],
    this.scrollable = false,
  });

  /// Dialog headline, e.g. "Change Password".
  final String title;

  /// Optional supporting text shown under the title.
  final String? message;

  /// Optional leading icon. Tinted with [iconColor] when provided.
  final IconData? icon;

  /// Tint used for the icon circle. Defaults to [AppColors.primary].
  final Color? iconColor;

  /// Body below the header — usually a form.
  final Widget? content;

  /// Action widgets, rendered right-aligned at the bottom.
  final List<Widget> actions;

  /// Whether the content should scroll when it overflows.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = iconColor ?? colors.primary;

    return Dialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: tint),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textHigh,
                height: 1.3,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                style: TextStyle(
                  fontSize: 13.5,
                  color: colors.textMedium,
                  height: 1.5,
                ),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: 20),
              Flexible(
                child: scrollable
                    ? SingleChildScrollView(child: content)
                    : content!,
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              // Wrap (not Row) so wide action pairs like "Cancel" +
              // "Delete Account" flow onto a second right-aligned line
              // instead of overflowing the dialog width.
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows an [AppDialog] and returns the value popped from the navigator.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  IconData? icon,
  Color? iconColor,
  Widget? content,
  List<Widget> actions = const <Widget>[],
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AppDialog(
      title: title,
      message: message,
      icon: icon,
      iconColor: iconColor,
      content: content,
      actions: actions,
    ),
  );
}

/// Shows a confirmation [AppDialog] with a cancel + confirm button.
///
/// Pass [destructive] to style the confirm button as an urgent action
/// (e.g. "Delete Account"). Returns `true` when the user confirms.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline,
  bool destructive = false,
}) async {
  final colors = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: title,
      message: message,
      icon: destructive ? Icons.warning_amber_rounded : icon,
      iconColor: destructive ? colors.urgent : colors.secondary,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: colors.urgent,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Standard filled dialog action button. Disables itself while [loading].
class DialogActionButton extends StatelessWidget {
  const DialogActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.destructive = false,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Shows a progress indicator and blocks taps while saving.
  final bool loading;

  /// Renders with the urgent color instead of primary.
  final bool destructive;

  final bool autofocus;

  /// Slightly tighter than the default so two actions fit on one line.
  static const _actionPadding = EdgeInsets.symmetric(horizontal: 18);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FilledButton(
      autofocus: autofocus,
      style: destructive
          ? FilledButton.styleFrom(
              backgroundColor: colors.urgent,
              foregroundColor: Colors.white,
              padding: _actionPadding,
            )
          : FilledButton.styleFrom(padding: _actionPadding),
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(label),
    );
  }
}
