import '../../domain/entities/blood_group.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/medical_history.dart';
import '../../domain/entities/medical_report.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/patient_account.dart';

/// Stores and reads the patient profile on the backend.
abstract interface class ProfileRemoteDataSource {
  Future<void> savePatientProfile(Map<String, Object?> payload);

  Future<PatientAccount> fetchAccount();

  /// Updates only the columns the patient may change. The phone number is not
  /// among them — it belongs to the verified session.
  /// Answers the stored record, or null when the response carried none.
  Future<PatientAccount?> updateDetails(Map<String, Object?> payload);

  /// Cheaper than [fetchAccount] — checks only for the row's existence.
  Future<bool> hasProfile();

  /// The patient's own account of their health.
  Future<MedicalHistory> fetchMedicalHistory();

  /// Replaces it. A full write rather than a merge, because the form owns every
  /// list on it and an entry the patient deleted has to actually disappear.
  Future<MedicalHistory> saveMedicalHistory(Map<String, Object?> payload);

  Future<NotificationSettings> fetchSettings();

  /// [payload] carries only the switch that moved, so a stale screen cannot
  /// undo a change made on another device.
  Future<NotificationSettings> updateSettings(Map<String, Object?> payload);

  /// Uploads a profile photo from [filePath] and answers with the API path it
  /// is served from. Null [filePath] is not a case here — the picker returns
  /// null for a cancel and the caller stops there.
  Future<String?> uploadPhoto(String filePath);

  /// Removes it. Answers null, which is what the account then reports.
  Future<String?> removePhoto();

  /// Erases the account for good. Answers with the moment the number may be
  /// used to sign up again — see `PatientsService.deleteAccount` on the API.
  Future<DateTime?> deleteAccount();

  /// The reports on file, newest first.
  Future<List<MedicalReport>> fetchReports();

  /// Uploads one, and answers with the stored record.
  ///
  /// [title] may be empty, in which case the API falls back to the file's own
  /// name — somebody who photographed a result and tapped Save has still told
  /// you more than "Report 4" would.
  Future<MedicalReport> uploadReport({
    required String filePath,
    required String title,
    MedicalRecordKind kind = MedicalRecordKind.report,
  });

  Future<void> deleteReport(String id);
}

/// Stand-in until the profile API exists. Swap for an HTTP implementation —
/// nothing above this layer changes.
class FakeProfileRemoteDataSource implements ProfileRemoteDataSource {
  FakeProfileRemoteDataSource();

  /// Held for the run, so the stub behaves like a store rather than like a
  /// constant: saving a medical record and reading it back agrees, which is
  /// what makes the form usable with no backend.
  MedicalHistory _history = MedicalHistory(
    conditions: const ['Asthma', 'Seasonal Allergies'],
    medications: const ['Albuterol Inhaler'],
    allergies: const ['Penicillin'],
    lastUpdated: DateTime(2024, 10, 12),
  );

  NotificationSettings _settings = const NotificationSettings();

  String? _photoPath;

  @override
  Future<void> savePatientProfile(Map<String, Object?> payload) {
    return Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Future<PatientAccount?> updateDetails(Map<String, Object?> payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return null;
  }

  /// The stub models a first-time patient, so the onboarding path stays
  /// exercisable without a backend. [fetchAccount] still returns an account
  /// for the screens that read one.
  @override
  Future<bool> hasProfile() async => false;

  @override
  Future<PatientAccount> fetchAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    return PatientAccount(
      id: 'patient-1',
      fullName: 'Alexander Wright',
      email: 'alexander.wright@gmail.com',
      phoneNumber: '+1 (555) 234-5678',
      dateOfBirth: DateTime(1991, 5, 18),
      gender: Gender.male,
      bloodGroup: BloodGroup.oPositive,
      avatarUrl: _photoPath,
      medicalHistory: _history,
    );
  }

  @override
  Future<MedicalHistory> fetchMedicalHistory() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _history;
  }

  @override
  Future<MedicalHistory> saveMedicalHistory(
    Map<String, Object?> payload,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    _history = MedicalHistory(
      conditions: _listOf(payload['conditions']),
      medications: _listOf(payload['medications']),
      allergies: _listOf(payload['allergies']),
      surgeries: _listOf(payload['surgeries']),
      notes: payload['notes'] as String?,
      // Stamped here, as the server would: the summary quotes it, so a stub
      // that left it alone would keep showing a date the record no longer has.
      lastUpdated: DateTime.now(),
    );

    return _history;
  }

  @override
  Future<NotificationSettings> fetchSettings() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _settings;
  }

  @override
  Future<NotificationSettings> updateSettings(
    Map<String, Object?> payload,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    for (final toggle in PatientNotificationToggle.values) {
      if (payload[toggle.name] case final bool value) {
        _settings = toggle.applyTo(_settings, value);
      }
    }

    return _settings;
  }

  @override
  Future<String?> uploadPhoto(String filePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    // The local file, so the stub actually shows the photo that was picked.
    // `RemoteAvatar` passes a value with no scheme to the API base, which is
    // wrong for a device path — the fake backend is only ever used in tests
    // and on a device with no API, where the avatar falls back to initials.
    _photoPath = filePath;
    return _photoPath;
  }

  @override
  Future<String?> removePhoto() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _photoPath = null;
    return null;
  }

  @override
  Future<List<MedicalReport>> fetchReports() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_reports);
  }

  @override
  Future<MedicalReport> uploadReport({
    required String filePath,
    required String title,
    MedicalRecordKind kind = MedicalRecordKind.report,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final fileName = filePath.split(RegExp(r'[\\/]')).last;
    final report = MedicalReport(
      id: 'report-${_reports.length + 1}',
      title: title.trim().isEmpty ? fileName : title.trim(),
      fileName: fileName,
      mimeType: fileName.toLowerCase().endsWith('.pdf')
          ? 'application/pdf'
          : 'image/jpeg',
      sizeBytes: 840_000,
      uploadedAt: DateTime.now(),
      kind: kind,
    );

    _reports.insert(0, report);
    return report;
  }

  @override
  Future<void> deleteReport(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _reports.removeWhere((report) => report.id == id);
  }

  @override
  Future<DateTime?> deleteAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // Free to sign up again at once, as with the API.
    return DateTime.now();
  }

  /// Held for the run, like `_photoPath`: uploading one and reading it back has
  /// to agree, or the screen is untestable without an API.
  final List<MedicalReport> _reports = [];

  static List<String> _listOf(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];
}
