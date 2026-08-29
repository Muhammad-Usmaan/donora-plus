import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shorthand accessor for semantic color tokens.
///
/// Usage:
/// ```dart
/// context.colors.urgent   // #E63946
/// context.colors.success  // #2E7D32
/// ```
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  MediaQueryData get mq => MediaQuery.of(this);
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  void showSnackBar(String message, {bool isError = false}) {
    final colors = Theme.of(this).extension<AppColors>() ?? AppColors.light;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? colors.urgent : colors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

extension StringX on String {
  /// Capitalize the first letter.
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Truncate with ellipsis.
  String truncate(int max) => length <= max ? this : '${substring(0, max)}…';
}

extension DateTimeX on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}

/// Helpers for detecting and formatting network-related errors.
extension ObjectErrorX on Object {
  /// Returns `true` when the error looks like a connectivity problem
  /// rather than a logic or validation issue.
  bool get isNetworkError {
    final s = toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('network') ||
        s.contains('timeout') ||
        s.contains('connection') ||
        s.contains('failed host') ||
        s.contains('no internet') ||
        s.contains('offline');
  }

  /// Converts an error into a short, user-friendly message.
  String get friendlyMessage {
    if (isNetworkError) {
      return 'No internet connection. Please check your network and try again.';
    }
    final s = toString();
    if (s.length > 120) return 'Something went wrong. Please try again.';
    return s;
  }
}
