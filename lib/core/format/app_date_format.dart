import '../l10n/tr.dart';

/// Date formatting the app needs, without pulling in `intl`.
///
/// Fixed-format: every date the design shows is one of these shapes. Month,
/// weekday and relative words go through [tr] so they follow the app's
/// language; digits stay Latin.
class AppDateFormat {
  const AppDateFormat._();

  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// `Aug` for a zero-based index — what a month wheel scrolls through.
  static String monthLabelAt(int index) => tr(_shortMonths[index]);

  /// Monday first, matching [DateTime.weekday] where Monday is 1.
  static const List<String> _shortWeekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// `12 Aug`
  static String dayMonth(DateTime date) =>
      '${date.day} ${tr(_shortMonths[date.month - 1])}';

  /// `21 Sep 2026` — a heading for a day far enough out that the weekday alone
  /// does not place it.
  ///
  /// Carries the year always rather than only when it differs from this one. A
  /// schedule is read at a glance, and "21 Sep" on a list that runs into
  /// January is a date the reader has to work out the year of.
  static String dayMonthYear(DateTime date) => '${dayMonth(date)} ${date.year}';

  /// `Mon`
  static String weekdayShort(DateTime date) =>
      tr(_shortWeekdays[date.weekday - 1]);

  /// True when [date] falls on the same calendar day as [other].
  ///
  /// Compared by date parts rather than by a duration, because "within 24
  /// hours" and "today" are different questions: 11pm and 1am are two hours
  /// apart and two different days, which is exactly the case a schedule has to
  /// get right.
  static bool isSameDay(DateTime date, DateTime other) =>
      date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;

  /// `Today` / `Tomorrow` / `21 Sep 2026` — how a schedule heading reads.
  ///
  /// The two relative labels matter more than they look: a doctor scanning a
  /// list wants to know what is happening *now* before what is happening on the
  /// 15th, and a date is something you have to work out.
  static String dayLabel(DateTime date, {DateTime? now}) {
    final today = now ?? DateTime.now();

    if (isSameDay(date, today)) return tr('Today');
    if (isSameDay(date, today.add(const Duration(days: 1)))) {
      return tr('Tomorrow');
    }
    if (isSameDay(date, today.subtract(const Duration(days: 1)))) {
      return tr('Yesterday');
    }

    return dayMonthYear(date);
  }

  /// `Oct 12, 2024`
  static String monthDayYear(DateTime date) =>
      '${tr(_shortMonths[date.month - 1])} ${date.day}, ${date.year}';

  /// `Just now`, `2 min ago`, `1 hr ago` — how long ago [time] was.
  ///
  /// Coarse on purpose: a queue that ticks every second reads as jittery, and
  /// the doctor only needs the order of magnitude. Pass [now] to make the
  /// result deterministic in a test.
  static String relativeSince(DateTime time, {DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(time);

    // A clock skew that puts [time] in the future still reads as "Just now"
    // rather than as a negative wait.
    if (elapsed.inMinutes < 1) return tr('Just now');
    if (elapsed.inMinutes < 60) {
      return tr('{count} min ago', {'count': elapsed.inMinutes});
    }
    if (elapsed.inHours < 24) {
      return tr('{count} hr ago', {'count': elapsed.inHours});
    }

    final days = elapsed.inDays;
    return days == 1
        ? tr('Yesterday')
        : tr('{count} days ago', {'count': days});
  }

  /// `10:30 AM`, or `10:30 am` with [lowercaseMeridiem] — chat bubbles set it
  /// quieter than a schedule does.
  static String clockTime(DateTime time, {bool lowercaseMeridiem = false}) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final meridiem = time.hour < 12 ? 'AM' : 'PM';

    return '$hour:$minute '
        '${lowercaseMeridiem ? meridiem.toLowerCase() : meridiem}';
  }
}
