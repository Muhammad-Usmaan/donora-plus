import 'package:intl/intl.dart';

/// Date, number, and string formatters used across the app.
class Formatters {
  const Formatters._();

  /// e.g. "Aug 28, 2026"
  static String dateShort(DateTime dt) =>
      DateFormat('MMM d, yyyy').format(dt);

  /// e.g. "Aug 28, 2026 3:45 PM"
  static String dateTimeShort(DateTime dt) =>
      DateFormat('MMM d, yyyy h:mm a').format(dt);

  /// Relative time: "2 hours ago", "just now", etc.
  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return dateShort(dt);
  }

  /// Phone number formatted as "+63 9XX XXX XXXX"
  static String phonePh(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('09')) {
      return '+63 ${digits.substring(1, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
    }
    return raw;
  }

  /// Distance in km with 1 decimal place: "3.2 km"
  static String distanceKm(double meters) =>
      '${(meters / 1000).toStringAsFixed(1)} km';
}
