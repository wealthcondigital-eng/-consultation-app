import '../../../../core/logging/auth_logger.dart';
import '../../../../core/network/api_client.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/entities/speciality.dart';
import '../../../profile/domain/entities/medical_history.dart';
import '../../domain/entities/doctor_appointment.dart';
import '../../domain/entities/doctor_dashboard.dart';
import '../../domain/entities/home_feed.dart';
import '../../domain/entities/patient_dashboard.dart';
import 'home_remote_data_source.dart';

/// The home screens, on the consultation API.
///
/// | Method | Path                    |
/// | ------ | ----------------------- |
/// | GET    | /doctors/me/dashboard   | the doctor's day, in one read
/// | PATCH  | /doctors/me/presence    | the online dial
/// | GET    | /patients/me/dashboard  | the patient's own numbers and state
/// | GET    | /doctors                | approved doctors, for the patient feed
class ApiHomeRemoteDataSource implements HomeRemoteDataSource {
  const ApiHomeRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  Future<DoctorDashboard> fetchDoctorDashboard() async {
    // `scope=upcoming` asks for the whole schedule ahead rather than the rest
    // of the current day, which is what the dashboard now groups by date. An
    // API that does not know the parameter ignores it and answers with today
    // as before, so this is safe to send against either version — and the
    // grouping degrades to a single "Today" heading rather than breaking.
    final body = await _client.get('/doctors/me/dashboard?scope=upcoming');

    final dashboard = body['dashboard'];
    if (dashboard is! Map<String, Object?>) {
      // A doctor with no record yet. The screen opens on its empty state rather
      // than an error — there is nothing wrong, there is just nothing yet.
      return const DoctorDashboard.empty();
    }

    final stats = dashboard['stats'];

    return DoctorDashboard(
      doctorName: dashboard['doctorName'] as String? ?? '',
      speciality: dashboard['speciality'] as String? ?? '',
      isOnline: dashboard['isOnline'] == true,
      stats: stats is Map<String, Object?>
          ? DoctorDayStats(
              consults: (stats['consults'] as num?)?.toInt() ?? 0,
              patients: (stats['patients'] as num?)?.toInt() ?? 0,
              rating: (stats['rating'] as num?)?.toDouble() ?? 0,
              earningsToday: (stats['earningsToday'] as num?)?.toInt() ?? 0,
              completedTotal: (stats['completedTotal'] as num?)?.toInt() ?? 0,
            )
          : const DoctorDayStats(),
      photoUrl: dashboard['photoUrl'] as String?,
      appointments: _appointmentsFrom(dashboard['appointments']),
    );
  }

  @override
  Future<PatientDashboard> fetchPatientDashboard() async {
    final body = await _client.get('/patients/me/dashboard');

    final dashboard = body['dashboard'];
    if (dashboard is! Map<String, Object?>) {
      // A patient with no record yet. The screen opens on its empty state
      // rather than an error — there is nothing wrong, there is just nothing
      // yet.
      return const PatientDashboard.empty();
    }

    final stats = dashboard['stats'];
    final active = dashboard['active'];

    AuthLogger.event('API · patient dashboard read', {
      'patientName': dashboard['patientName'],
      'photoUrl': dashboard['photoUrl'],
      'profileCompleteness': stats is Map
          ? stats['profileCompleteness']
          : '(no stats)',
    });

    return PatientDashboard(
      patientName: dashboard['patientName'] as String? ?? '',
      firstName: dashboard['firstName'] as String?,
      photoUrl: dashboard['photoUrl'] as String?,
      profileComplete: dashboard['profileComplete'] == true,
      consultations: stats is Map<String, Object?>
          ? (stats['consultations'] as num?)?.toInt() ?? 0
          : 0,
      doctorsSeen: stats is Map<String, Object?>
          ? (stats['doctorsSeen'] as num?)?.toInt() ?? 0
          : 0,
      spend: stats is Map<String, Object?>
          ? (stats['spend'] as num?)?.toInt() ?? 0
          : 0,
      profileCompleteness: stats is Map<String, Object?>
          ? (stats['profileCompleteness'] as num?)?.toInt() ?? 0
          : 0,
      active: active is Map<String, Object?>
          ? _patientAppointmentFrom(active)
          : null,
      recent: dashboard['recent'] is List
          ? [
              for (final row
                  in (dashboard['recent'] as List)
                      .whereType<Map<String, Object?>>())
                if (row['id'] is String) _patientAppointmentFrom(row),
            ]
          : const [],
      specialities: _specialitiesFrom(dashboard['specialities']),
      medicalHistory: _medicalHistoryFrom(dashboard['medicalHistory']),
    );
  }

  /// What this patient has consulted, commonest first.
  ///
  /// Empty for a new account, which the home screen draws as no section at all.
  /// It used to be a fixed row of four tiles headed "Popular Specialities" that
  /// the app carried itself — the same for everybody, popular with nobody, and
  /// filtering on ids (`cardiology`) that no doctor record matches (`Cardiology`),
  /// so every tile led to an empty list.
  static List<Speciality> _specialitiesFrom(Object? value) {
    if (value is! List) return const [];

    return [
      for (final row in value.whereType<Map<String, Object?>>())
        if (row['id'] case final String id when id.trim().isNotEmpty)
          Speciality.named(id),
    ];
  }

  /// One consultation as the patient's own list reads it.
  ///
  /// The same wire shape `ApiAppointmentRemoteDataSource` parses, mapped again
  /// here rather than shared: the dashboard carries these rows inline, and
  /// importing a data source from another feature's data layer to reuse one
  /// private mapper would be a worse coupling than twenty lines.
  static Appointment _patientAppointmentFrom(Map<String, Object?> json) {
    final scheduledAt =
        DateTime.tryParse(json['scheduledAt'] as String? ?? '')?.toLocal() ??
        DateTime.tryParse(json['startsAt'] as String? ?? '')?.toLocal();

    return Appointment(
      id: json['id'] as String? ?? '',
      kind: AppointmentKind.from(
        json['kind'] ?? json['type'],
        scheduledAt: scheduledAt,
      ),
      scheduledAt: scheduledAt,
      counterpartName: json['doctorName'] as String? ?? 'Doctor',
      counterpartSubtitle: json['doctorSpeciality'] as String? ?? '',
      counterpartId: json['doctorId'] as String?,
      mode: json['mode'] == 'audio'
          ? ConsultationMode.audio
          : ConsultationMode.video,
      status: AppointmentStatus.from(json['status'] as String?),
      requestedAt:
          DateTime.tryParse(json['requestedAt'] as String? ?? '') ??
          DateTime.now(),
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? ''),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      fee: (json['fee'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toInt(),
      isAnonymous: json['isAnonymous'] == true,
      channelId: json['channelId'] as String?,
      concern: switch (json['concern']) {
        final String text when text.trim().isNotEmpty => text.trim(),
        _ => null,
      },
      // The receipt, so the dashboard's card can open the same bill the
      // appointment list does.
      paymentId: json['paymentId'] as String?,
      paidAt: DateTime.tryParse(json['paidAt'] as String? ?? '')?.toLocal(),
      counterpartRegistrationNumber:
          json['doctorRegistrationNumber'] as String?,
      paymentStatus: PaymentStatus.from(json['paymentStatus']),
      paymentMethod: json['paymentMethod'] as String?,
      amountPaid: (json['amountPaid'] as num?)?.toInt(),
      platformFee: (json['platformFee'] as num?)?.toInt(),
      refundedAmount: (json['refundedAmount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Null when the patient has recorded nothing, which the dashboard shows as
  /// an invitation rather than as four empty lists.
  static MedicalHistory? _medicalHistoryFrom(Object? value) {
    if (value is! Map<String, Object?>) return null;

    final updatedAt = value['updated_at'] as String?;

    return MedicalHistory(
      conditions: _stringsOf(value['conditions']),
      medications: _stringsOf(value['medications']),
      allergies: _stringsOf(value['allergies']),
      surgeries: _stringsOf(value['surgeries']),
      notes: value['notes'] as String?,
      lastUpdated: updatedAt == null ? null : DateTime.tryParse(updatedAt),
    );
  }

  static List<String> _stringsOf(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

  @override
  Future<void> setDoctorOnline(bool isOnline) async {
    await _client.patch('/doctors/me/presence', body: {'isOnline': isOnline});
  }

  @override
  Future<HomeFeed> fetchHomeFeed() async {
    final body = await _client.get('/doctors?limit=10');

    return HomeFeed(
      // Overlaid by the controller from the patient's own record, so a value
      // here would only be discarded.
      patientFirstName: null,
      // **Empty.** The specialities on the home screen are the patient's own
      // now, and they come from their dashboard — `PatientDashboard
      // .specialities` — because what somebody has consulted is a real answer
      // and a fixed list of four is not. The feed is the catalogue, and the
      // catalogue has no opinion about which four a given person cares about.
      specialities: const [],
      doctors: _doctorsFrom(body['doctors']),
    );
  }

  static List<Doctor> _doctorsFrom(Object? value) {
    if (value is! List) return const [];

    return [
      for (final row in value.whereType<Map<String, Object?>>())
        if (row['id'] is String)
          Doctor(
            id: row['id'] as String,
            name: row['name'] as String? ?? 'Doctor',
            speciality: row['speciality'] as String? ?? 'General Physician',
            yearsOfExperience: (row['yearsOfExperience'] as num?)?.toInt() ?? 0,
            rating: (row['rating'] as num?)?.toDouble() ?? 0,
            consultationFee: (row['consultationFee'] as num?)?.toInt() ?? 0,
            audioConsultationFee: (row['audioConsultationFee'] as num?)
                ?.toInt(),
            isVerified: row['isVerified'] == true,
            isAvailableNow: row['isAvailableNow'] == true,
          ),
    ];
  }

  static List<DoctorAppointment> _appointmentsFrom(Object? value) {
    if (value is! List) return const [];

    return [
      for (final row in value.whereType<Map<String, Object?>>())
        if (row['id'] is String)
          DoctorAppointment(
            id: row['id'] as String,
            patientName: row['patientName'] as String? ?? 'Patient',
            patientId: switch (row['patientId']) {
              final String id when id.isNotEmpty => id,
              _ => null,
            },
            patientPhotoUrl: switch (row['patientPhotoUrl']) {
              final String path when path.isNotEmpty => path,
              _ => null,
            },
            mode: row['mode'] == 'audio'
                ? ConsultationMode.audio
                : ConsultationMode.video,
            // Local time. It travels as UTC and this is shown to somebody
            // reading a clock on a wall.
            startsAt:
                DateTime.tryParse(
                  row['startsAt'] as String? ?? '',
                )?.toLocal() ??
                DateTime.now(),
            status: switch (row['status']) {
              'in_progress' => DoctorAppointmentStatus.inProgress,
              'waiting' => DoctorAppointmentStatus.waiting,
              _ => DoctorAppointmentStatus.confirmed,
            },
            isAnonymous: row['isAnonymous'] == true,
            kind: AppointmentKind.from(
              row['kind'],
              scheduledAt: DateTime.tryParse(
                row['scheduledAt'] as String? ?? '',
              ),
            ),
            concern: switch (row['concern']) {
              final String text when text.trim().isNotEmpty => text.trim(),
              _ => null,
            },
          ),
    ];
  }
}
