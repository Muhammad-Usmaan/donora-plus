import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Pill badge for urgent blood requests.
///
/// Urgent accent background (#E63946) with white text and a pulsing-dot
/// icon animation. Used ONLY for urgent-request badges — visually distinct
/// from Primary crimson so "urgent" always reads as emergency.
///
/// Always pairs icon + text — never relies on color alone (a11y).
class UrgentRequestBadge extends StatelessWidget {
  const UrgentRequestBadge({super.key, this.compact = false});

  /// When true, shows only the dot icon without text (for tight spaces).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: colors.urgent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: Colors.white, size: compact ? 6 : 8),
          if (!compact) ...[
            const SizedBox(width: 6),
            const Text(
              'Urgent',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small pulsing dot animation for the urgent badge.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return Opacity(
          opacity: 0.5 + (_controller.value * 0.5),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
