import 'package:consultation_app/features/doctor_onboarding/domain/entities/doctor_availability.dart';
import 'package:consultation_app/features/scheduling/domain/entities/schedule_builder.dart';
import 'package:consultation_app/features/scheduling/domain/entities/time_slot.dart';
import 'package:flutter_test/flutter_test.dart';

AvailabilitySlot _window(int fromHour, int toHour) => AvailabilitySlot(
  start: ClockTime(hour: fromHour, minute: 0),
  end: ClockTime(hour: toHour, minute: 0),
);

/// A Monday, early enough in the day that nothing has passed yet.
final _mondayMorning = DateTime(2026, 9, 14, 7, 0);

void main() {
  group('ScheduleBuilder', () {
    test('offers the doctor their own hours, not invented surgery hours', () {
      final schedule = ScheduleBuilder.fromAvailability(
        availability: DoctorAvailability(
          days: {Weekday.monday},
          slots: {_window(18, 21)},
        ),
        from: _mondayMorning,
        horizon: 1,
      );

      expect(schedule.days, hasLength(1));
      expect(schedule.days.single.slots.map((slot) => slot.timeLabel), [
        '06:00 PM',
        '06:30 PM',
        '07:00 PM',
        '07:30 PM',
        '08:00 PM',
        '08:30 PM',
      ]);
    });

    test('an evening clinic is filed under evening', () {
      // It used to come back as an afternoon one, so a practice running 6–9pm
      // appeared to start its afternoon after dark.
      final schedule = ScheduleBuilder.fromAvailability(
        availability: DoctorAvailability(
          days: {Weekday.monday},
          slots: {_window(18, 20)},
        ),
        from: _mondayMorning,
        horizon: 1,
      );

      expect(
        schedule.days.single.slots.every(
          (slot) => slot.period == SlotPeriod.evening,
        ),
        isTrue,
      );
    });

    test('no slot runs past the end of the window', () {
      // A 30-minute consultation starting at 11:45 would overrun hours the
      // doctor never agreed to.
      final schedule = ScheduleBuilder.fromAvailability(
        availability: DoctorAvailability(
          days: {Weekday.monday},
          slots: {
            const AvailabilitySlot(
              start: ClockTime(hour: 9, minute: 0),
              end: ClockTime(hour: 10, minute: 15),
            ),
          },
        ),
        from: _mondayMorning,
        horizon: 1,
      );

      expect(schedule.days.single.slots.map((slot) => slot.timeLabel), [
        '09:00 AM',
        '09:30 AM',
      ]);
    });

    test('days the doctor does not work are left off the strip', () {
      // An empty day is a tap that leads nowhere.
      final schedule = ScheduleBuilder.fromAvailability(
        availability: DoctorAvailability(
          days: {Weekday.wednesday},
          slots: {_window(9, 11)},
        ),
        from: _mondayMorning,
        horizon: 7,
      );

      expect(schedule.days, hasLength(1));
      expect(schedule.days.single.date.weekday, DateTime.wednesday);
    });

    test('today does not offer times that have already passed', () {
      final schedule = ScheduleBuilder.fromAvailability(
        availability: DoctorAvailability(
          days: {Weekday.monday},
          slots: {_window(9, 12)},
        ),
        // Mid-morning: the 9:00, 9:30 and 10:00 starts are gone.
        from: DateTime(2026, 9, 14, 10, 15),
        horizon: 1,
      );

      expect(schedule.days.single.slots.map((slot) => slot.timeLabel), [
        '10:30 AM',
        '11:00 AM',
        '11:30 AM',
      ]);
    });

    test('a day whose slots have all passed drops out entirely', () {
      final schedule = ScheduleBuilder.fromAvailability(
        availability: DoctorAvailability(
          days: {Weekday.monday},
          slots: {_window(9, 12)},
        ),
        from: DateTime(2026, 9, 14, 23, 0),
        horizon: 1,
      );

      expect(schedule.days, isEmpty);
    });

    test('a booked slot stays on the grid, greyed out', () {
      // Removing it would leave a hole the patient cannot tell from the doctor
      // simply not working then.
      final schedule = ScheduleBuilder.fromAvailability(
        availability: DoctorAvailability(
          days: {Weekday.monday},
          slots: {_window(9, 11)},
        ),
        from: _mondayMorning,
        horizon: 1,
        booked: {DateTime(2026, 9, 14, 9, 30)},
      );

      final slots = schedule.days.single.slots;
      expect(slots, hasLength(4));
      expect(
        slots.firstWhere((slot) => slot.timeLabel == '09:30 AM').isAvailable,
        isFalse,
      );
      expect(schedule.days.single.hasOpenSlots, isTrue);
    });

    test('two windows in a day come back in time order', () {
      final schedule = ScheduleBuilder.fromAvailability(
        availability: DoctorAvailability(
          days: {Weekday.monday},
          // Deliberately out of order: a Set has no order to trust.
          slots: {_window(15, 16), _window(9, 10)},
        ),
        from: _mondayMorning,
        horizon: 1,
      );

      expect(schedule.days.single.slots.map((slot) => slot.timeLabel), [
        '09:00 AM',
        '09:30 AM',
        '03:00 PM',
        '03:30 PM',
      ]);
    });

    test('a doctor with no availability set is bookable on no day', () {
      final schedule = ScheduleBuilder.fromAvailability(
        availability: const DoctorAvailability(),
        from: _mondayMorning,
      );

      expect(schedule.days, isEmpty);
    });

    test('the consultation length sets how far apart slots start', () {
      final schedule = ScheduleBuilder.fromAvailability(
        availability: DoctorAvailability(
          days: {Weekday.monday},
          slots: {_window(9, 10)},
        ),
        from: _mondayMorning,
        consultation: const Duration(minutes: 20),
        horizon: 1,
      );

      expect(schedule.days.single.slots.map((slot) => slot.timeLabel), [
        '09:00 AM',
        '09:20 AM',
        '09:40 AM',
      ]);
      expect(schedule.consultationDuration, const Duration(minutes: 20));
    });
  });
}
