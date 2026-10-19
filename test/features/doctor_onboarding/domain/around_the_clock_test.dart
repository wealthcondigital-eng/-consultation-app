import 'package:consultation_app/features/doctor_onboarding/domain/entities/doctor_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a doctor who is always available', () {
    test('is every day, midnight to midnight', () {
      final always = DoctorAvailability.alwaysOn();

      expect(always.isAroundTheClock, isTrue);
      expect(always.days, hasLength(7));
      expect(always.slots.single, AvailabilityPresets.allDay);
    });

    test('runs to the midnight that ends the day, not 23:59', () {
      // The API's `endMinute` allows 1440 precisely so a window can close the
      // day. 23:59 leaves a minute out, and 00:00 points at the start of the
      // day the window began on.
      expect(AvailabilityPresets.allDay.end.minutesSinceMidnight, 1440);
      expect(AvailabilityPresets.allDay.isValid, isTrue);
    });

    test('says so on the profile rather than listing seven days', () {
      expect(DoctorAvailability.alwaysOn().summaryLabel, 'Available 24/7');
    });

    test('is not claimed for a full week of ordinary hours', () {
      // Every day *and* a window is not the same as every day around the
      // clock, and a doctor consulting 9 to 5 seven days a week must not be
      // advertised as reachable at three in the morning.
      final busyWeek = DoctorAvailability(
        days: Weekday.values.toSet(),
        slots: {
          const AvailabilitySlot(
            start: ClockTime(hour: 9, minute: 0),
            end: ClockTime(hour: 17, minute: 0),
          ),
        },
      );

      expect(busyWeek.isAroundTheClock, isFalse);
      expect(busyWeek.summaryLabel, 'Every day · 1 slot');
    });
  });

  group('the midnight that ends a day', () {
    test('reads as midnight rather than noon', () {
      // `24 % 12 == 0` is the same arithmetic as `12`, so the hour formatter
      // used to call it 12:00 PM — the far end of the day from where it is.
      expect(ClockTime.endOfDay.label, '12:00 AM');
      expect(ClockTime.endOfDay.paddedLabel, '12:00 AM');
    });

    test('leaves ordinary times alone', () {
      expect(const ClockTime(hour: 0, minute: 0).label, '12:00 AM');
      expect(const ClockTime(hour: 8, minute: 0).label, '8:00 AM');
      expect(const ClockTime(hour: 12, minute: 30).label, '12:30 PM');
      expect(const ClockTime(hour: 17, minute: 0).label, '5:00 PM');
    });
  });
}
