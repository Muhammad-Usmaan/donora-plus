import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Small verified badge: check_circle icon + "Verified" in Success green.
///
/// Used next to verified donor names in cards, chat headers, and lists.
/// Always pairs icon + text — never relies on color alone.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.compact = false});

  /// When true, shows only the icon (for tight spaces).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (compact) {
      return Semantics(
        label: 'Verified donor',
        child: Icon(
          Icons.check_circle,
          size: 16,
          color: colors.success,
        ),
      );
    }

    return Semantics(
      label: 'Verified donor',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: colors.success),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.success,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
