import 'package:flutter/material.dart';

/// Semantic color tokens for Donora+.
///
/// Registered as a [ThemeExtension] on [ThemeData] so every widget
/// retrieves them via:
/// ```dart
/// final colors = Theme.of(context).extension<AppColors>()!;
/// ```
/// Or the shorthand from `core/utils/extensions.dart`:
/// ```dart
/// context.colors.urgent
/// ```
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.primaryContainer,
    required this.urgent,
    required this.urgentContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.success,
    required this.warning,
    required this.textHigh,
    required this.textMedium,
    required this.border,
    required this.surface,
    required this.card,
    required this.volunteer,
    required this.compensated,
    required this.chatbotGradientEdge,
    required this.chatbotGradientCenter,
  });

  /// Brand crimson — primary buttons, active nav icon, brand mark.
  /// Use sparingly: this is a healthcare app, not a warning app.
  final Color primary;

  /// Tinted crimson background — BloodTypeChip fill, subtle highlights.
  final Color primaryContainer;

  /// Emergency accent — ONLY for urgent badges, SOS buttons, emergency banners.
  /// Must be visually distinct from [primary] so "urgent" always reads as urgent.
  final Color urgent;

  /// Tinted urgent background for urgent-related surfaces.
  final Color urgentContainer;

  /// Calm teal — maps, verified badges, chat bubbles, secondary actions.
  final Color secondary;

  /// Tinted teal background — verified surfaces, secondary highlights.
  final Color secondaryContainer;

  /// Verified status, success confirmations.
  final Color success;

  /// Warnings, compensated-donor tags, caution states.
  final Color warning;

  /// Neutral-900 — text high emphasis (headings, body).
  final Color textHigh;

  /// Neutral-600 — text medium emphasis (captions, secondary text).
  final Color textMedium;

  /// Neutral-300 — borders, dividers, card outlines.
  final Color border;

  /// Neutral-100 — scaffold background.
  final Color surface;

  /// White — card surfaces.
  final Color card;

  /// Volunteer donor chip color (teal).
  final Color volunteer;

  /// Compensated-for-travel/time donor chip color (amber).
  /// Never red, never implies "paid".
  final Color compensated;

  /// Dark charcoal — left/right edge of the AI chatbot card gradient.
  /// Matches the marketing website hero section edges (#1B1B1F).
  final Color chatbotGradientEdge;

  /// Dark charcoal — center stop of the AI chatbot card gradient.
  /// Slightly warmer than [chatbotGradientEdge] (#231C20).
  final Color chatbotGradientCenter;

  /// Default light color tokens.
  static const light = AppColors(
    primary: Color(0xFFC62828),
    primaryContainer: Color(0xFFFDEAEA),
    urgent: Color(0xFFE63946),
    urgentContainer: Color(0xFFFDE8E9),
    secondary: Color(0xFF2A6F77),
    secondaryContainer: Color(0xFFE2F1F2),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFF9A825),
    textHigh: Color(0xFF1B1B1F),
    textMedium: Color(0xFF52525B),
    border: Color(0xFFE4E4E7),
    surface: Color(0xFFF7F7F9),
    card: Color(0xFFFFFFFF),
    volunteer: Color(0xFF2A6F77),
    compensated: Color(0xFFF9A825),
    chatbotGradientEdge: Color(0xFF1B1B1F),
    chatbotGradientCenter: Color(0xFF231C20),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryContainer,
    Color? urgent,
    Color? urgentContainer,
    Color? secondary,
    Color? secondaryContainer,
    Color? success,
    Color? warning,
    Color? textHigh,
    Color? textMedium,
    Color? border,
    Color? surface,
    Color? card,
    Color? volunteer,
    Color? compensated,
    Color? chatbotGradientEdge,
    Color? chatbotGradientCenter,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      urgent: urgent ?? this.urgent,
      urgentContainer: urgentContainer ?? this.urgentContainer,
      secondary: secondary ?? this.secondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      textHigh: textHigh ?? this.textHigh,
      textMedium: textMedium ?? this.textMedium,
      border: border ?? this.border,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      volunteer: volunteer ?? this.volunteer,
      compensated: compensated ?? this.compensated,
      chatbotGradientEdge: chatbotGradientEdge ?? this.chatbotGradientEdge,
      chatbotGradientCenter: chatbotGradientCenter ?? this.chatbotGradientCenter,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      urgent: Color.lerp(urgent, other.urgent, t)!,
      urgentContainer: Color.lerp(urgentContainer, other.urgentContainer, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryContainer: Color.lerp(secondaryContainer, other.secondaryContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      textHigh: Color.lerp(textHigh, other.textHigh, t)!,
      textMedium: Color.lerp(textMedium, other.textMedium, t)!,
      border: Color.lerp(border, other.border, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      volunteer: Color.lerp(volunteer, other.volunteer, t)!,
      compensated: Color.lerp(compensated, other.compensated, t)!,
      chatbotGradientEdge: Color.lerp(chatbotGradientEdge, other.chatbotGradientEdge, t)!,
      chatbotGradientCenter: Color.lerp(chatbotGradientCenter, other.chatbotGradientCenter, t)!,
    );
  }
}
