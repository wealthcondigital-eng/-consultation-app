import '../../../../core/format/app_date_format.dart';
import 'time_slot.dart';

/// One day on the date strip, with the slots the doctor offers on it.
class ScheduleDay {
  const ScheduleDay({
    required this.date,
    required this.slots,
    this.isToday = false,
  });

  final DateTime date;
  final List<TimeSlot> slots;

  /// Marked by the backend rather than compared against the device clock, so a
  /// day cannot read as "today" only because the phone's date is off.
  final bool isToday;

  /// `MON`
  String get weekdayLabel => AppDateFormat.weekdayShort(date).toUpperCase();

  /// `18`
  String get dayLabel => date.day.toString();

  /// `Mon, 18 Aug` — the day spelled out, for use away from the strip.
  String get dateLabel =>
      '${AppDateFormat.weekdayShort(date)}, ${AppDateFormat.dayMonth(date)}';

  List<TimeSlot> slotsIn(SlotPeriod period) =>
      slots.where((slot) => slot.period == period).toList();

  bool get hasOpenSlots => slots.any((slot) => slot.isAvailable);
}
