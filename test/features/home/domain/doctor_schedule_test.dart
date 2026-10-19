import 'package:consultation_app/features/appointments/domain/entities/appointment.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/home/domain/entities/doctor_appointment.dart';
import 'package:consultation_app/features/home/domain/entities/doctor_dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fixed clock. Every expectation here is about a time relative to "now", and
/// a test that reads the real one is a test that starts failing on a date
/// nobody chose.
final DateTime _now = DateTime(2026, 9, 21, 12, 0);

DoctorAppointment _booking(
  DateTime startsAt, {
  DoctorAppointmentStatus status = DoctorAppointmentStatus.confirmed,
  String id = 'booking',
}) {
  return DoctorAppointment(
    id: id,
    patientName: 'Rahul Sharma',
    mode: ConsultationMode.video,
    startsAt: startsAt,
    status: status,
    kind: AppointmentKind.scheduled,
  );
}

void main() {
  group('a slot that has been and gone', () {
    test('is over once the consultation would have finished', () {
      final passed = _booking(_now.subtract(const Duration(hours: 2)));

      expect(passed.isOver(now: _now), isTrue);
    });

    test('is not over while the doctor is merely running late', () {
      // The grace window is one consultation's length, so a doctor who opens
      // the app four minutes after the hour still has a way into a call the
      // patient is sitting in.
      final justStarted = _booking(_now.subtract(const Duration(minutes: 4)));

      expect(justStarted.isOver(now: _now), isFalse);
    });

    test('is never over while it is actually happening', () {
      final running = _booking(
        _now.subtract(const Duration(hours: 3)),
        status: DoctorAppointmentStatus.inProgress,
      );

      expect(running.isOver(now: _now), isFalse);
    });

    test('does not apply to an instant consultation', () {
      // A patient waiting on the line has no slot to run out of — the server
      // ends it when they give up, and dropping the row here would take the
      // call off the doctor's screen while somebody was still holding.
      final instant = DoctorAppointment(
        id: 'instant',
        patientName: 'Rahul Sharma',
        mode: ConsultationMode.audio,
        startsAt: _now.subtract(const Duration(hours: 4)),
        status: DoctorAppointmentStatus.waiting,
      );

      expect(instant.isOver(now: _now), isFalse);
    });
  });

  group('the dashboard schedule', () {
    test('leaves out the slots that have passed', () {
      final dashboard = DoctorDashboard(
        doctorName: 'Dr. Noren Joseph',
        speciality: 'Cardiology',
        appointments: [
          _booking(_now.subtract(const Duration(hours: 3)), id: 'this-morning'),
          _booking(_now.add(const Duration(hours: 2)), id: 'this-afternoon'),
        ],
      );

      final days = dashboard.appointmentDays(now: _now);

      expect(days, hasLength(1));
      expect(days.single.appointments.single.id, 'this-afternoon');
    });

    test('reads as empty when everything on it is over', () {
      final dashboard = DoctorDashboard(
        doctorName: 'Dr. Noren Joseph',
        speciality: 'Cardiology',
        appointments: [_booking(_now.subtract(const Duration(hours: 5)))],
      );

      expect(dashboard.hasAppointmentsAt(now: _now), isFalse);
    });

    test('heads the days Today, Tomorrow, then the date', () {
      final dashboard = DoctorDashboard(
        doctorName: 'Dr. Noren Joseph',
        speciality: 'Cardiology',
        appointments: [
          _booking(_now.add(const Duration(hours: 1)), id: 'today'),
          _booking(_now.add(const Duration(days: 1)), id: 'tomorrow'),
          _booking(_now.add(const Duration(days: 4)), id: 'later'),
        ],
      );

      expect(dashboard.appointmentDays(now: _now).map((day) => day.label), [
        'Today',
        'Tomorrow',
        '25 Sep 2026',
      ]);
    });
  });
}
