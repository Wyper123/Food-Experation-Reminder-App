import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String short(DateTime d) => DateFormat('MMM d, yyyy').format(d);

  static String compact(DateTime d) => DateFormat('MMM d').format(d);

  /// Long label, e.g. "3 days left", "Expired 2d ago".
  static String daysLabel(int days) {
    if (days < 0) return 'Expired ${-days}d ago';
    if (days == 0) return 'Expires today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }

  /// Short label for badges, e.g. "5d left".
  static String daysShort(int days) {
    if (days < 0) return '${-days}d overdue';
    if (days == 0) return 'Today';
    return '${days}d left';
  }

  static String relativeTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inHours < 48) return 'Yesterday';
    return short(d);
  }
}
