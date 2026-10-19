import '../../../../core/error/failure.dart';
import '../../../doctor_onboarding/domain/entities/bank_account.dart';
import '../../domain/entities/doctor_credential.dart';
import '../../domain/entities/doctor_earnings.dart';
import '../../domain/entities/doctor_patient.dart';
import '../../domain/entities/doctor_patient_detail.dart';
import '../../domain/entities/doctor_review.dart';
import '../../domain/entities/doctor_practice_profile.dart';
import '../../domain/entities/doctor_settings.dart';
import '../../domain/repositories/doctor_practice_repository.dart';
import '../datasources/doctor_practice_remote_data_source.dart';

class DoctorPracticeRepositoryImpl implements DoctorPracticeRepository {
  const DoctorPracticeRepositoryImpl(this._remoteDataSource);

  final DoctorPracticeRemoteDataSource _remoteDataSource;

  @override
  Future<DoctorPracticeProfile> fetchProfile() =>
      _guard(_remoteDataSource.fetchProfile);

  @override
  Future<DoctorPracticeProfile> updateProfile(DoctorProfileEdits edits) =>
      _guard(() => _remoteDataSource.updateProfile(edits.toPayload()));

  @override
  Future<String?> uploadPhoto(String filePath) =>
      _guard(() => _remoteDataSource.uploadPhoto(filePath));

  @override
  Future<String?> removePhoto() => _guard(_remoteDataSource.removePhoto);

  @override
  Future<List<DoctorPatient>> fetchPatients({String? search, int limit = 50}) {
    return _guard(
      () => _remoteDataSource.fetchPatients(search: search, limit: limit),
    );
  }

  @override
  Future<DoctorPatientDetail> fetchPatientDetail(String patientId) =>
      _guard(() => _remoteDataSource.fetchPatientDetail(patientId));

  @override
  Future<List<DoctorReview>> fetchReviews({int limit = 50}) =>
      _guard(() => _remoteDataSource.fetchReviews(limit: limit));

  @override
  Future<DoctorEarnings> fetchEarnings(EarningsPeriod period) =>
      _guard(() => _remoteDataSource.fetchEarnings(period));

  @override
  Future<BankAccountSummary> fetchBankAccount() =>
      _guard(_remoteDataSource.fetchBankAccount);

  @override
  Future<BankAccountSummary> saveBankAccount(BankAccount account) =>
      _guard(() => _remoteDataSource.saveBankAccount(account));

  @override
  Future<List<DoctorCredential>> fetchCredentials() =>
      _guard(_remoteDataSource.fetchCredentials);

  @override
  Future<DoctorCredential> addCertificate({
    required String title,
    required String filePath,
    required String contentType,
  }) => _guard(
    () => _remoteDataSource.addCertificate(
      title: title,
      filePath: filePath,
      contentType: contentType,
    ),
  );

  @override
  Future<void> removeCertificate(String id) =>
      _guard(() => _remoteDataSource.removeCertificate(id));

  @override
  Future<DoctorSettings> fetchSettings() =>
      _guard(_remoteDataSource.fetchSettings);

  @override
  Future<DoctorSettings> setNotificationPreference(
    DoctorNotificationToggle toggle,
    bool value,
  ) {
    return _guard(
      () => _remoteDataSource.updateSettings(toggle.payload(value)),
    );
  }

  /// A `Failure` passes through with its message intact; anything else becomes
  /// the generic one rather than reaching a screen as a stack trace.
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
