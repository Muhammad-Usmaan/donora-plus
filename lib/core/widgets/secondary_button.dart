import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Outlined secondary action button.
///
/// Neutral-300 border, Neutral-900 text, 12px radius, 48px height.
/// Used for "Cancel", "Skip", and other secondary actions.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colors.textHigh,
          side: BorderSide(color: context.colors.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.colors.textMedium,
                ),
              )
            : Text(label),
      ),
    );
  }
}
