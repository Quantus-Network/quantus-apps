import 'package:intl/intl.dart';

class FormattedDuration {
  final String hours;
  final String minutes;
  final String seconds;
  final String formatted;

  const FormattedDuration({
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.formatted,
  });

  // Optional: Override toString for easy printing
  @override
  String toString() =>
      'FormattedDuration(hours: $hours, minutes: $minutes, seconds: $seconds, formatted: $formatted)';
}

// A utility class to format DateTime objects into human-readable "time ago" strings.
class DatetimeFormattingService {
  /// Formats a given [dateTime] into a human-readable "time ago" string.
  ///
  /// Examples: "just now", "5 minutes ago", "2 hours ago", "yesterday",
  /// "2 days ago", "3 months ago", "1 year ago", "in 5 minutes", "in 2 days".
  static String format(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime.toLocal());

    // Use padLeft to ensure that single-digit numbers have a leading zero.
    String hours = dateTime.hour.toString().padLeft(2, '0');
    String minutes = dateTime.minute.toString().padLeft(2, '0');
    String timeString = '$hours:$minutes';

    // Handle future dates (e.g., "in 5 minutes")
    if (difference.isNegative) {
      final positiveDifference = dateTime.difference(now);
      return '${_formatFuture(positiveDifference)} $timeString';
    }

    // Handle past dates (e.g., "5 minutes ago")
    return '${_formatPast(difference)} $timeString';
  }

  static FormattedDuration formatDuration(Duration duration) {
    if (duration.isNegative) {
      return const FormattedDuration(
        hours: '00',
        minutes: '00',
        seconds: '00',
        formatted: '00:00:00',
      );
    }

    // Use padLeft to ensure that single-digit numbers have a leading zero.
    String hours = duration.inHours.toString().padLeft(2, '0');
    String minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    String seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return FormattedDuration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      formatted: '$hours:$minutes:$seconds',
    );
  }

  static String formatTimestamp(DateTime timestamp) {
    return DateFormat('dd-MM-yyyy HH:mm:ss').format(timestamp.toLocal());
  }

  /// Helper function to format future durations.
  static String _formatFuture(Duration duration) {
    if (duration.inSeconds < 10) {
      return 'just now'; // Or "in a moment"
    } else if (duration.inMinutes < 1) {
      return 'in ${duration.inSeconds} seconds';
    } else if (duration.inHours < 1) {
      return 'in ${duration.inMinutes} minute${_pluralize(duration.inMinutes)}';
    } else if (duration.inDays < 1) {
      return 'in ${duration.inHours} hour${_pluralize(duration.inHours)}';
    } else if (duration.inDays < 2) {
      return 'tomorrow';
    } else if (duration.inDays < 7) {
      return 'in ${duration.inDays} day${_pluralize(duration.inDays)}';
    } else if (duration.inDays < 30) {
      final weeks = (duration.inDays / 7).ceil();
      return 'in $weeks week${_pluralize(weeks)}';
    } else if (duration.inDays < 365) {
      final months = (duration.inDays / 30).ceil(); // Approximation for months
      return 'in $months month${_pluralize(months)}';
    } else {
      final years = (duration.inDays / 365).ceil(); // Approximation for years
      return 'in $years year${_pluralize(years)}';
    }
  }

  /// Helper function to format past durations.
  static String _formatPast(Duration duration) {
    if (duration.inSeconds < 10) {
      return 'just now';
    } else if (duration.inMinutes < 1) {
      return '${duration.inSeconds} second${_pluralize(duration.inSeconds)} ago';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes} minute${_pluralize(duration.inMinutes)} ago';
    } else if (duration.inDays < 1) {
      return '${duration.inHours} hour${_pluralize(duration.inHours)} ago';
    } else if (duration.inDays < 2) {
      return 'yesterday';
    } else if (duration.inDays < 7) {
      return '${duration.inDays} day${_pluralize(duration.inDays)} ago';
    } else if (duration.inDays < 30) {
      final weeks = (duration.inDays / 7).ceil();
      return '$weeks week${_pluralize(weeks)} ago';
    } else if (duration.inDays < 365) {
      final months = (duration.inDays / 30).ceil(); // Approximation for months
      return '$months month${_pluralize(months)} ago';
    } else {
      final years = (duration.inDays / 365).ceil(); // Approximation for years
      return '$years year${_pluralize(years)} ago';
    }
  }

  /// Helper function to add 's' for pluralization.
  static String _pluralize(int count) {
    return count == 1 ? '' : 's';
  }
}
