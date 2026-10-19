import '../../../../core/l10n/tr.dart';
import 'schedule_day.dart';
import 'time_slot.dart';

/// One open slot with the day it falls on.
///
/// The grid splits the two — a day holds its slots — but anywhere a slot is
/// quoted away from the grid it has to carry its date, or "09:00" means nothing.
class OpenSlot {
  const OpenSlot({required this.day, required this.slot});

  final ScheduleDay day;
  final TimeSlot slot;

  /// The moment the consultation starts.
  DateTime get startsAt => DateTime(
    day.date.year,
    day.date.month,
    day.date.day,
    slot.hour,
    slot.minute,
  );

  /// `Today, 02:30 PM` / `Mon, 18 Aug · 09:00 AM`
  String get label => day.isToday
      ? tr('Today, {time}', {'time': slot.timeLabel})
      : '${day.dateLabel} · ${slot.timeLabel}';
}

/// What a doctor has open over the coming days.
class DoctorSchedule {
  const DoctorSchedule({
    required this.days,
    required this.consultationDuration,
  });

  /// Earliest first, starting with today.
  final List<ScheduleDay> days;

  /// How long the appointment itself runs.
  final Duration consultationDuration;

  /// True when anything at all can be booked in the days covered.
  bool get hasOpenSlots => days.any((day) => day.hasOpenSlots);

  /// The soonest open slots, earliest first.
  ///
  /// What a doctor's profile quotes so a patient can see when they are next
  /// free without opening the booking screen and reading a grid — the question
  /// asked of an offline doctor is "when can I see you", and the answer was
  /// two taps away.
  List<OpenSlot> nextOpen({int limit = 3}) {
    final open = <OpenSlot>[];

    for (final day in days) {
      for (final slot in day.slots) {
        if (!slot.isAvailable) continue;

        open.add(OpenSlot(day: day, slot: slot));
        if (open.length == limit) return open;
      }
    }

    return open;
  }

  /// `30 minutes`
  String get durationLabel {
    final minutes = consultationDuration.inMinutes;
    if (minutes < 60) return tr('{count} minutes', {'count': minutes});

    final hours = consultationDuration.inHours;
    final remainder = minutes % 60;
    final hourLabel = hours == 1
        ? tr('1 hour')
        : tr('{count} hours', {'count': hours});
    return remainder == 0
        ? hourLabel
        : tr('{hours} {minutes} minutes', {
            'hours': hourLabel,
            'minutes': remainder,
          });
  }
}
