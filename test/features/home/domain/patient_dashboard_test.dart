import 'package:consultation_app/features/appointments/domain/entities/appointment.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/home/domain/entities/patient_dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _row(
  String id, {
  String? doctorId,
  bool anonymous = false,
  AppointmentStatus status = AppointmentStatus.completed,
}) => Appointment(
  id: id,
  counterpartName: 'Dr. $id',
  counterpartId: doctorId,
  mode: ConsultationMode.video,
  status: status,
  requestedAt: DateTime(2026, 9, 21),
  isAnonymous: anonymous,
);

void main() {
  test('the last consultation skips the one with its own banner', () {
    final live = _row('live', status: AppointmentStatus.inProgress);
    final dashboard = PatientDashboard(
      active: live,
      recent: [live, _row('done')],
    );

    expect(dashboard.lastConsultation?.id, 'done');
  });

  test('recent doctors are one per doctor, newest first, never anonymous', () {
    final dashboard = PatientDashboard(
      recent: [
        _row('a', doctorId: 'd1'),
        _row('b', doctorId: 'd2', anonymous: true),
        _row('c', doctorId: 'd1'),
        _row('d', doctorId: 'd3'),
        _row('e'),
      ],
    );

    expect(dashboard.recentDoctors.map((row) => row.id), ['a', 'd']);
  });
}
