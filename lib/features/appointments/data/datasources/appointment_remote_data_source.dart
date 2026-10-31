import '../../../../core/network/api_client.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../domain/entities/appointment.dart';

/// Where each role's list is served from.
///
/// Here rather than as a field on `AppointmentAudience`, which lives in the
/// domain and must not know about routes — the layering rule in
/// ARCHITECTURE.md, and the reason this file is the only one that changes if a
/// path does.
///
/// A switch rather than a map, so the analyzer fails the day a third audience
/// is added. A map lookup returns null for the case nobody filled in, and this
/// value goes straight into a URL — `null?filter=all` would reach the server as
/// a 404 rather than as a compile error.
String _pathFor(AppointmentAudience audience) => switch (audience) {
  AppointmentAudience.patient => '/patients/me/appointments',
  AppointmentAudience.doctor => '/doctors/me/appointments',
};

/// Supplies the appointment lists.
abstract interface class AppointmentRemoteDataSource {
  Future<List<Appointment>> fetchAppointments({
    required AppointmentAudience audience,
    required AppointmentFilter filter,
    int limit,
  });
}

/// The appointment lists, on the consultation API.
///
/// | Method | Path                      |
/// | ------ | ------------------------- |
/// | GET    | /patients/me/appointments | ?filter= &limit=
/// | GET    | /doctors/me/appointments  | ?filter= &limit=
class ApiAppointmentRemoteDataSource implements AppointmentRemoteDataSource {
  const ApiAppointmentRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  Future<List<Appointment>> fetchAppointments({
    required AppointmentAudience audience,
    required AppointmentFilter filter,
    int limit = 30,
  }) async {
    final body = await _client.get(
      '${_pathFor(audience)}?filter=${filter.query}&limit=$limit',
    );

    final rows = body['appointments'];
    if (rows is! List) return const [];

    return [
      for (final row in rows.whereType<Map<String, Object?>>())
        if (row['id'] is String) _toAppointment(row, audience),
    ];
  }

  static Appointment _toAppointment(
    Map<String, Object?> json,
    AppointmentAudience audience,
  ) {
    final requestedAt =
        DateTime.tryParse(json['requestedAt'] as String? ?? '')?.toLocal() ??
        DateTime.now();

    // `scheduledAt` is the booked time; `startsAt` is what the doctor's
    // dashboard calls the same field. Both are read, because the two API
    // processes disagree and a booking that parses as instant is a booking
    // whose time is never shown.
    //
    // Local, because every screen that shows it is showing it to somebody
    // reading a clock on a wall.
    final scheduledAt =
        DateTime.tryParse(json['scheduledAt'] as String? ?? '')?.toLocal() ??
        DateTime.tryParse(json['startsAt'] as String? ?? '')?.toLocal();

    return Appointment(
      id: json['id'] as String,
      kind: AppointmentKind.from(
        json['kind'] ?? json['type'],
        scheduledAt: scheduledAt,
      ),
      scheduledAt: scheduledAt,
      counterpartName: switch (audience) {
        AppointmentAudience.patient =>
          json['doctorName'] as String? ?? 'Doctor',
        AppointmentAudience.doctor =>
          json['patientName'] as String? ?? 'Patient',
      },
      counterpartSubtitle: switch (audience) {
        AppointmentAudience.patient =>
          json['doctorSpeciality'] as String? ?? '',
        // A patient has no title to put under their name. The doctor's row
        // shows the fee and the outcome instead, which is what they look for.
        AppointmentAudience.doctor => '',
      },
      counterpartId: switch (audience) {
        AppointmentAudience.patient => json['doctorId'] as String?,
        AppointmentAudience.doctor => json['patientId'] as String?,
      },
      mode: json['mode'] == 'audio'
          ? ConsultationMode.audio
          : ConsultationMode.video,
      status: AppointmentStatus.from(json['status'] as String?),
      requestedAt: requestedAt,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '')?.toLocal(),
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '')?.toLocal(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      fee: (json['fee'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toInt(),
      isAnonymous: json['isAnonymous'] == true,
      channelId: json['channelId'] as String?,
      concern: switch (json['concern']) {
        final String text when text.trim().isNotEmpty => text.trim(),
        _ => null,
      },
      // The receipt fields. Absent on an older row, which reads as a row with
      // no receipt rather than an error.
      paymentId:
          json['paymentId'] as String? ?? json['razorpayPaymentId'] as String?,
      paidAt: DateTime.tryParse(json['paidAt'] as String? ?? '')?.toLocal(),
      // Only ever the doctor's: a patient has no registration number, so the
      // doctor's own list leaves this null.
      counterpartRegistrationNumber: switch (audience) {
        AppointmentAudience.patient =>
          json['doctorRegistrationNumber'] as String?,
        AppointmentAudience.doctor => null,
      },
      paymentStatus: PaymentStatus.from(json['paymentStatus']),
      paymentMethod: json['paymentMethod'] as String?,
      amountPaid: (json['amountPaid'] as num?)?.toInt(),
      platformFee: (json['platformFee'] as num?)?.toInt(),
      refundedAmount: (json['refundedAmount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Sample history until a device has a backend. Swap for the API
/// implementation — nothing above this layer changes.
class FakeAppointmentRemoteDataSource implements AppointmentRemoteDataSource {
  const FakeAppointmentRemoteDataSource();

  @override
  Future<List<Appointment>> fetchAppointments({
    required AppointmentAudience audience,
    required AppointmentFilter filter,
    int limit = 30,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final now = DateTime.now();
    final isPatient = audience == AppointmentAudience.patient;

    final rows = [
      Appointment(
        id: 'appointment-live',
        counterpartName: isPatient ? 'Dr. Sunita Rao' : 'Rahul Sharma',
        counterpartSubtitle: isPatient ? 'Pediatrician' : '',
        counterpartId: 'counterpart-1',
        mode: ConsultationMode.video,
        status: AppointmentStatus.inProgress,
        requestedAt: now.subtract(const Duration(minutes: 4)),
        startedAt: now.subtract(const Duration(minutes: 3)),
        durationSeconds: 180,
        fee: 600,
        channelId: 'consult-sample-live',
      ),
      Appointment(
        id: 'appointment-done',
        counterpartName: isPatient ? 'Dr. Vinay Kumar' : 'Meera Iyer',
        counterpartSubtitle: isPatient ? 'Cardiologist' : '',
        counterpartId: 'counterpart-2',
        mode: ConsultationMode.audio,
        status: AppointmentStatus.completed,
        requestedAt: now.subtract(const Duration(days: 2, minutes: 30)),
        startedAt: now.subtract(const Duration(days: 2, minutes: 29)),
        endedAt: now.subtract(const Duration(days: 2, minutes: 17)),
        durationSeconds: 720,
        fee: 900,
        rating: 5,
        // The completed row carries a full receipt, so the offline build can
        // open one. A patient sees the doctor's registration; a doctor looking
        // at their own list sees no counterpart registration, because a
        // patient has none.
        paymentId: 'pay_NqXsAmpLe0192',
        paidAt: now.subtract(const Duration(days: 2, minutes: 31)),
        counterpartRegistrationNumber: isPatient ? 'KA-2009-11238' : null,
      ),
      Appointment(
        id: 'appointment-expired',
        counterpartName: isPatient ? 'Finding a doctor' : 'Patient Hawk',
        mode: ConsultationMode.video,
        status: AppointmentStatus.expired,
        requestedAt: now.subtract(const Duration(days: 6)),
        endedAt: now.subtract(const Duration(days: 6)),
        isAnonymous: !isPatient,
      ),
      // A booking, so the stub exercises the second kind and the grouping that
      // separates them. Without one the offline build could only ever render a
      // list of instant consultations.
      Appointment(
        id: 'appointment-booked',
        counterpartName: isPatient ? 'Dr. Anita Desai' : 'Farah Khan',
        counterpartSubtitle: isPatient ? 'Dermatologist' : '',
        counterpartId: 'counterpart-3',
        kind: AppointmentKind.scheduled,
        mode: ConsultationMode.video,
        status: AppointmentStatus.accepted,
        requestedAt: now.subtract(const Duration(hours: 6)),
        scheduledAt: now.add(const Duration(days: 1, hours: 2)),
        fee: 750,
      ),
    ];

    // Filtered here rather than returned wholesale, so the stub exercises the
    // same three-way control the real screen drives.
    return rows
        .where(
          (row) => switch (filter) {
            AppointmentFilter.all => true,
            AppointmentFilter.upcoming => row.isUpcoming(),
            AppointmentFilter.past => !row.isUpcoming(),
          },
        )
        .take(limit)
        .toList();
  }
}
