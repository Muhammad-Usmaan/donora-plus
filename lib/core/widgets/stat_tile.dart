import 'package:flutter/material.dart';

import '../utils/extensions.dart';

/// One value + caption tile used in the 3-stat rows
/// (Blood Type / Donated / Requested) on profile screens.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.caption,
    this.valueColor,
  });

  /// Large bold value, e.g. "A+" or "12".
  final String value;

  /// Small caption under the value, e.g. "Blood Type".
  final String caption;

  /// Optional accent for the value (defaults to high-emphasis text).
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: valueColor ?? colors.textHigh,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textMedium,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
