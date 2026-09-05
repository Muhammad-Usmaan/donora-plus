import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../theme/app_colors.dart';
import '../utils/extensions.dart';

/// Compact icon + label badge that distinguishes blood from platelet requests.
///
/// - Blood: drop icon + primary (crimson) accent.
/// - Platelet: test-tube icon + secondary (teal) accent.
///
/// Used on request cards (feed, list, detail) so both types are identifiable
/// at a glance even in a mixed list.
class DonationTypeBadge extends StatelessWidget {
  const DonationTypeBadge({
    super.key,
    required this.donationType,
    this.compact = false,
  });

  /// 'blood' or 'platelet' — matches the DB CHECK constraint values.
  final String donationType;

  /// Smaller padding and font for tight card headers.
  final bool compact;

  bool get _isPlatelet => donationType == 'platelet';

  Color _accent(AppColors colors) =>
      _isPlatelet ? colors.secondary : colors.primary;

  IconData get _icon =>
      _isPlatelet ? PhosphorIconsRegular.testTube : PhosphorIconsRegular.drop;

  String get _label => _isPlatelet ? 'Platelets' : 'Blood';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = _accent(colors);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            _icon,
            size: compact ? 12 : 14,
            color: accent,
          ),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
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
