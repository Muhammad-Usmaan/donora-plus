import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Pill-shaped chip displaying a blood type (A+, B-, O+, etc.).
///
/// Default: Primary Container background with Primary text.
/// Selected: Primary fill with white text.
/// Uses 999px border-radius (pill shape) per the design system.
class BloodTypeChip extends StatelessWidget {
  const BloodTypeChip({
    super.key,
    required this.bloodType,
    this.selected = false,
    this.onTap,
  });

  final String bloodType;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          bloodType,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : colors.primary,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
