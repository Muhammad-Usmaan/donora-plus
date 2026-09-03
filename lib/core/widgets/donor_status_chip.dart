import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Pill chip showing donor classification.
///
/// - "Volunteer" → teal chip (uses [AppColors.volunteer])
/// - "Compensated for travel/time" → amber chip (uses [AppColors.compensated])
///
/// Never red, never says "Paid" — per the design system and product spec.
class DonorStatusChip extends StatelessWidget {
  const DonorStatusChip({
    super.key,
    required this.classification,
  });

  /// One of: 'volunteer', 'compensated'
  final String classification;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isVolunteer = classification == 'volunteer';

    final color = isVolunteer ? colors.volunteer : colors.compensated;
    final label = isVolunteer
        ? 'Volunteer'
        : 'Compensated for travel/time';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVolunteer ? Icons.favorite_outline : Icons.directions_walk,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
