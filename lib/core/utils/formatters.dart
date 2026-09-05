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

  /// Human-readable countdown to an expiry timestamp.
  ///
  /// Returns strings like "Expires in 3h", "Expires in 45m",
  /// or "Expires in 2d" depending on the remaining time.
  static String expiresCountdown(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    if (remaining.inHours < 1) return 'Expires in ${remaining.inMinutes}m';
    if (remaining.inHours < 24) return 'Expires in ${remaining.inHours}h';
    return 'Expires in ${remaining.inDays}d';
  }

  /// "Needed by [date]" label for planned (non-urgent) requests.
  static String neededBy(DateTime plannedDate) {
    return 'Needed by ${dateShort(plannedDate)}';
  }

  /// Relative future date: "in 12 days", "in 3 months", "in 2 years".
  ///
  /// Returns "Today" if the date is today, or falls back to [dateShort]
  /// if the date is in the past.
  static String relativeDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    if (diff <= 0) return 'Today';
    if (diff < 30) return 'in $diff day${diff == 1 ? '' : 's'}';
    if (diff < 365) {
      final months = (diff / 30).round();
      return 'in $months month${months == 1 ? '' : 's'}';
    }
    final years = (diff / 365).round();
    return 'in $years year${years == 1 ? '' : 's'}';
  }
}
