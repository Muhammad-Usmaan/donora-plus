import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Filled urgent action button.
///
/// Urgent accent color fill (#E63946), white text, 12px radius, 48px height.
/// Used ONLY for emergency actions like "Request Blood Now" or "SOS".
/// Must be visually distinct from [PrimaryButton] so "urgent" always reads.
class UrgentButton extends StatelessWidget {
  const UrgentButton({
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
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.urgent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              ),
      ),
    );
  }
}
