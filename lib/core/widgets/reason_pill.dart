import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../constants/request_reasons.dart';
import '../utils/extensions.dart';

/// Pill badge showing why blood is needed on request cards and detail.
///
/// Each reason maps to an existing palette accent (see
/// [RequestReasonStyle]) and follows the shared chip recipe:
/// 12% tint fill + 30% tint border + rounded-stroke icon.
class ReasonPill extends StatelessWidget {
  const ReasonPill({super.key, required this.reason});

  final RequestReason reason;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = reason.accent(colors);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(reason.icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            reason.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
