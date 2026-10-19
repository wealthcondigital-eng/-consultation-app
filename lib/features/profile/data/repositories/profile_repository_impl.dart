import '../../../../core/error/failure.dart';
import '../../domain/entities/medical_history.dart';
import '../../domain/entities/medical_report.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/patient_account.dart';
import '../../domain/entities/patient_details.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';
import '../models/patient_details_payload.dart';
import '../models/patient_profile_payload.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._remoteDataSource);

  final ProfileRemoteDataSource _remoteDataSource;

  @override
  Future<void> savePatientProfile(PatientProfile profile) {
    return _guard(
      () => _remoteDataSource.savePatientProfile(
        profile.toPayload(now: DateTime.now()),
      ),
    );
  }

  @override
  Future<PatientAccount?> updateDetails(PatientDetails details) {
    return _guard(() => _remoteDataSource.updateDetails(details.toPayload()));
  }

  @override
  Future<bool> hasProfile() => _guard(_remoteDataSource.hasProfile);

  @override
  Future<PatientAccount> fetchAccount() =>
      _guard(_remoteDataSource.fetchAccount);

  @override
  Future<MedicalHistory> fetchMedicalHistory() =>
      _guard(_remoteDataSource.fetchMedicalHistory);

  @override
  Future<MedicalHistory> saveMedicalHistory(MedicalHistory history) {
    return _guard(
      () => _remoteDataSource.saveMedicalHistory(history.toPayload()),
    );
  }

  @override
  Future<NotificationSettings> fetchSettings() =>
      _guard(_remoteDataSource.fetchSettings);

  @override
  Future<NotificationSettings> setNotificationPreference(
    PatientNotificationToggle toggle,
    bool value,
  ) {
    return _guard(
      () => _remoteDataSource.updateSettings(toggle.payload(value)),
    );
  }

  @override
  Future<String?> uploadPhoto(String filePath) =>
      _guard(() => _remoteDataSource.uploadPhoto(filePath));

  @override
  Future<DateTime?> deleteAccount() => _guard(_remoteDataSource.deleteAccount);

  @override
  Future<List<MedicalReport>> fetchReports() =>
      _guard(_remoteDataSource.fetchReports);

  @override
  Future<MedicalReport> uploadReport({
    required String filePath,
    required String title,
    MedicalRecordKind kind = MedicalRecordKind.report,
  }) {
    return _guard(
      () => _remoteDataSource.uploadReport(
        filePath: filePath,
        title: title,
        kind: kind,
      ),
    );
  }

  @override
  Future<void> deleteReport(String id) =>
      _guard(() => _remoteDataSource.deleteReport(id));

  @override
  Future<String?> removePhoto() => _guard(_remoteDataSource.removePhoto);

  /// A `Failure` passes through with its message intact; anything else — a
  /// cast, a null, a plugin throwing — becomes the generic one rather than
  /// reaching a screen as a stack trace.
  ///
  /// Written once here rather than as ten identical try/catch bodies, which is
  /// what this file used to be.
  static Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }
}
