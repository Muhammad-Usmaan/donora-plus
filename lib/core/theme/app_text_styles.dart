import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography tokens for Donora+.
///
/// Uses Inter (Google Fonts) for all UI text, falling back to the
/// system sans-serif font if Inter is unavailable.
///
/// Access via:
/// - `Theme.of(context).textTheme.*` (preferred — already wired in AppTheme)
/// - `AppTypography.display` etc. for direct references
class AppTypography {
  const AppTypography._();

  /// Inter font via Google Fonts with system sans-serif fallback.
  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    Color color = const Color(0xFF1B1B1F),
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // ── Display / Headline ─────────────────────────────────────────────
  /// 24sp / 700 — screen titles, hero numbers (e.g. blood group on card).
  static TextStyle get display => _inter(
        size: 24,
        weight: FontWeight.w700,
        height: 1.2,
      );

  // ── Headline ───────────────────────────────────────────────────────
  /// 20sp / 600 — section headings.
  static TextStyle get headline => _inter(
        size: 20,
        weight: FontWeight.w600,
        height: 1.3,
      );

  // ── Title ──────────────────────────────────────────────────────────
  /// 18sp / 600 — card titles, section headers.
  static TextStyle get title => _inter(
        size: 18,
        weight: FontWeight.w600,
        height: 1.3,
      );

  // ── Body ───────────────────────────────────────────────────────────
  /// 15sp / 400 — paragraph text, list items.
  static TextStyle get body => _inter(
        size: 15,
        weight: FontWeight.w400,
        height: 1.5,
      );

  /// 15sp / 400 — secondary body text (medium emphasis).
  static TextStyle get bodySecondary => _inter(
        size: 15,
        weight: FontWeight.w400,
        color: const Color(0xFF52525B),
        height: 1.5,
      );

  // ── Caption / Meta ─────────────────────────────────────────────────
  /// 12sp / 500, 0.4 letter-spacing — timestamps, distance, tags.
  static TextStyle get caption => _inter(
        size: 12,
        weight: FontWeight.w500,
        color: const Color(0xFF52525B),
        letterSpacing: 0.4,
        height: 1.4,
      );

  /// 12sp / 400 — helper text, hints.
  static TextStyle get hint => _inter(
        size: 12,
        weight: FontWeight.w400,
        color: const Color(0xFF52525B),
        height: 1.4,
      );

  // ── Label ──────────────────────────────────────────────────────────
  /// 11sp / 600, 0.8 letter-spacing — uppercase category labels
  /// (e.g. "BLOOD GROUP", "STATUS").
  static TextStyle get label => _inter(
        size: 11,
        weight: FontWeight.w600,
        color: const Color(0xFF52525B),
        letterSpacing: 0.8,
        height: 1.3,
      );

  // ── Button ─────────────────────────────────────────────────────────
  /// 15sp / 600, 0.2 letter-spacing — button labels.
  static TextStyle get button => _inter(
        size: 15,
        weight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.2,
      );
}
