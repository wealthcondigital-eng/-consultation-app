import '../../../doctor_onboarding/domain/entities/doctor_availability.dart';
import 'doctor_schedule.dart';
import 'schedule_day.dart';
import 'time_slot.dart';

/// Turns the weekly hours a doctor set into dated, bookable slots.
///
/// The two halves of scheduling were never joined up: doctors chose windows on
/// Set Availability, and patients were offered the same invented surgery hours
/// for everybody. This is the join — one doctor's Tuesday evenings are the only
/// thing a patient is offered on a Tuesday, and a doctor who works mornings
/// stops being bookable at three in the afternoon.
///
/// Pure, and deliberately so. It is what the backend will do server-side once
/// the scheduling API exists; keeping it here as a function over data means the
/// rule can be tested without a network, and the stub and the real client agree
/// on what a schedule *means* rather than each inventing one.
abstract final class ScheduleBuilder {
  /// How long a consultation runs, and therefore how far apart slots start.
  static const Duration defaultConsultation = Duration(minutes: 30);

  /// How far ahead a patient may book.
  static const int defaultHorizon = 7;

  /// Expands [availability] into [horizon] days of slots starting at [from].
  ///
  /// [booked] holds the exact start times already taken. Those slots stay on
  /// the grid greyed out rather than vanishing: a patient looking at a gap
  /// should be able to tell "the doctor does not work then" from "somebody got
  /// there first", and a day that silently loses half its chips looks broken.
  ///
  /// Days the doctor does not work are dropped entirely — an empty day on the
  /// strip is a tap that leads nowhere.
  static DoctorSchedule fromAvailability({
    required DoctorAvailability availability,
    required DateTime from,
    Duration consultation = defaultConsultation,
    int horizon = defaultHorizon,
    Set<DateTime> booked = const {},
  }) {
    final today = DateTime(from.year, from.month, from.day);
    final windows = availability.sortedSlots;

    final days = <ScheduleDay>[];

    for (var offset = 0; offset < horizon; offset++) {
      final date = today.add(Duration(days: offset));
      if (!availability.days.contains(_weekdayOf(date))) continue;

      final slots = _slotsFor(
        date: date,
        windows: windows,
        consultation: consultation,
        booked: booked,
        // Only today can have slots in the past.
        notBefore: offset == 0 ? from : null,
      );

      if (slots.isEmpty) continue;

      days.add(ScheduleDay(date: date, slots: slots, isToday: offset == 0));
    }

    return DoctorSchedule(days: days, consultationDuration: consultation);
  }

  static List<TimeSlot> _slotsFor({
    required DateTime date,
    required List<AvailabilitySlot> windows,
    required Duration consultation,
    required Set<DateTime> booked,
    DateTime? notBefore,
  }) {
    final step = consultation.inMinutes;
    if (step <= 0) return const [];

    final slots = <TimeSlot>[];

    for (final window in windows) {
      if (!window.isValid) continue;

      // The last start that still leaves room for the whole consultation. A
      // 30-minute slot beginning at the end of a window would run past the
      // hours the doctor actually agreed to.
      final lastStart = window.end.minutesSinceMidnight - step;

      for (
        var minute = window.start.minutesSinceMidnight;
        minute <= lastStart;
        minute += step
      ) {
        final start = DateTime(
          date.year,
          date.month,
          date.day,
          minute ~/ 60,
          minute % 60,
        );

        // A slot that has already begun cannot be booked, and one starting in
        // the next few minutes is not worth offering either.
        if (notBefore != null && !start.isAfter(notBefore)) continue;

        slots.add(
          TimeSlot(
            hour: start.hour,
            minute: start.minute,
            isAvailable: !booked.contains(start),
          ),
        );
      }
    }

    // Windows may be given in any order and may not be sorted by the set they
    // came from, so the grid is ordered here rather than trusted to arrive so.
    slots.sort(
      (a, b) => a.minutesSinceMidnight.compareTo(b.minutesSinceMidnight),
    );

    return slots;
  }

  /// `DateTime.weekday` counts Monday as 1; [Weekday] counts it as index 0.
  static Weekday _weekdayOf(DateTime date) => Weekday.values[date.weekday - 1];
}
