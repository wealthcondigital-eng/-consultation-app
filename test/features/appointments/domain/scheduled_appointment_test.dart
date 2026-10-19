import 'package:consultation_app/features/appointments/domain/entities/appointment.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/home/domain/entities/doctor_appointment.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _booking({
  required DateTime at,
  AppointmentStatus status = AppointmentStatus.scheduled,
  String? channelId = 'consult-room',
}) {
  return Appointment(
    id: 'booking',
    counterpartName: 'Dr. Anita Desai',
    mode: ConsultationMode.video,
    status: status,
    kind: AppointmentKind.scheduled,
    requestedAt: at.subtract(const Duration(days: 1)),
    scheduledAt: at,
    channelId: channelId,
  );
}

void main() {
  group('a scheduled appointment', () {
    final now = DateTime(2026, 9, 12, 10, 0);

    test('is read as confirmed, not as a search still running', () {
      // `scheduled` had no case at all, so an unknown status fell through to
      // `searching` — and a confirmed appointment on Thursday read as
      // "Finding a doctor" on both lists.
      expect(AppointmentStatus.from('scheduled'), AppointmentStatus.scheduled);
      expect(AppointmentStatus.scheduled.label, 'Confirmed');
      expect(AppointmentStatus.scheduled.outcome, AppointmentOutcome.pending);
    });

    test('is upcoming until its time passes', () {
      final thursday = _booking(at: now.add(const Duration(days: 2)));
      expect(thursday.isUpcoming(now: now), isTrue);

      final lastWeek = _booking(at: now.subtract(const Duration(days: 7)));
      expect(lastWeek.isUpcoming(now: now), isFalse);
    });

    test('sorts by the time it is for, not the time it was made', () {
      final booking = _booking(at: now.add(const Duration(days: 2)));

      expect(booking.occursAt, booking.scheduledAt);
      expect(booking.occursAt, isNot(booking.requestedAt));
    });

    test('cannot be rejoined days ahead of its slot', () {
      final thursday = _booking(at: now.add(const Duration(days: 2)));

      // It carries a channel from the moment it is made, so `channelId != null`
      // alone would put a Rejoin button on a Tuesday for a Thursday
      // appointment — a button that cannot work. The API refuses the join
      // outside the same window and is the authority.
      expect(thursday.isRejoinableAt(now: now), isFalse);
    });

    test('can be rejoined once its slot is close', () {
      final soon = _booking(at: DateTime.now().add(const Duration(minutes: 5)));

      expect(soon.isRejoinable, isTrue);
    });

    test('a booking with no room yet offers nothing to join', () {
      final soon = _booking(
        at: DateTime.now().add(const Duration(minutes: 5)),
        channelId: null,
      );

      expect(soon.isRejoinable, isFalse);
    });
  });

  group("a booking on the doctor's dashboard", () {
    test('opens only as its time comes round', () {
      final now = DateTime(2026, 9, 12, 10, 0);

      DoctorAppointment booking(DateTime at) => DoctorAppointment(
        id: 'booking',
        patientName: 'Farah Khan',
        mode: ConsultationMode.video,
        startsAt: at,
        status: DoctorAppointmentStatus.confirmed,
        kind: AppointmentKind.scheduled,
      );

      // Every `confirmed` row used to be refused outright, so a doctor with an
      // appointment at three o'clock still had no way into it at three
      // o'clock.
      expect(
        booking(now.add(const Duration(hours: 5))).isJoinable(now: now),
        isFalse,
      );
      expect(
        booking(now.add(const Duration(minutes: 10))).isJoinable(now: now),
        isTrue,
      );
      expect(booking(now).isJoinable(now: now), isTrue);
    });

    test('a live call is joinable whenever it is happening', () {
      final now = DateTime(2026, 9, 12, 10, 0);

      final waiting = DoctorAppointment(
        id: 'live',
        patientName: 'Rahul Sharma',
        mode: ConsultationMode.video,
        startsAt: now.subtract(const Duration(minutes: 2)),
        status: DoctorAppointmentStatus.waiting,
      );

      expect(waiting.isJoinable(now: now), isTrue);
    });

    test('carries what the patient wrote', () {
      final appointment = DoctorAppointment(
        id: 'booking',
        patientName: 'Patient Hawk',
        mode: ConsultationMode.audio,
        startsAt: DateTime(2026, 9, 14, 15, 0),
        status: DoctorAppointmentStatus.confirmed,
        kind: AppointmentKind.scheduled,
        concern: 'Trouble sleeping for a month.',
      );

      expect(appointment.concern, 'Trouble sleeping for a month.');
    });
  });
}
