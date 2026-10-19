import '../../../../core/error/failure.dart';
import '../../domain/entities/bank_account.dart';
import '../../domain/entities/doctor_application.dart';
import '../../domain/entities/doctor_availability.dart';
import '../../domain/entities/doctor_credentials.dart';
import '../../domain/entities/doctor_setup_options.dart';
import '../../domain/entities/medical_certificate.dart';
import '../../domain/entities/practice_setup.dart';
import '../../domain/repositories/doctor_onboarding_repository.dart';
import '../datasources/doctor_onboarding_remote_data_source.dart';

class DoctorOnboardingRepositoryImpl implements DoctorOnboardingRepository {
  const DoctorOnboardingRepositoryImpl(this._remoteDataSource);

  final DoctorOnboardingRemoteDataSource _remoteDataSource;

  @override
  Future<DoctorSetupOptions> fetchSetupOptions() =>
      _guard(_remoteDataSource.fetchSetupOptions);

  @override
  Future<DoctorCredentials> parseCertificate(MedicalCertificate certificate) {
    return _guard(() => _remoteDataSource.parseCertificate(certificate));
  }

  @override
  Future<DoctorApplication> submitApplication({
    required DoctorCredentials credentials,
    required BankAccount bankAccount,
    MedicalCertificate? certificate,
  }) {
    return _guard(
      () => _remoteDataSource.submitApplication(
        credentials: credentials,
        bankAccount: bankAccount,
        certificate: certificate,
      ),
    );
  }

  @override
  Future<DoctorApplication?> fetchMyApplication() async {
    try {
      return await _remoteDataSource.fetchMyApplication();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }

  @override
  Stream<DoctorApplication> watchApplication(String applicationId) {
    return _remoteDataSource.watchApplication(applicationId).handleError((
      Object error,
    ) {
      throw error is Failure ? error : const Failure.unexpected();
    });
  }

  @override
  Future<PracticeSetup> fetchPracticeSetup() =>
      _guard(_remoteDataSource.fetchPracticeSetup);

  @override
  Future<void> saveConsultationFees({int? videoFee, int? audioFee}) => _guard(
    () => _remoteDataSource.saveConsultationFees(
      videoFee: videoFee,
      audioFee: audioFee,
    ),
  );

  @override
  Future<DoctorAvailability> fetchAvailability() =>
      _guard(_remoteDataSource.fetchAvailability);

  @override
  Future<void> saveAvailability(DoctorAvailability availability) =>
      _guard(() => _remoteDataSource.saveAvailability(availability));

  /// Every call funnels through here so no transport-level error reaches the
  /// UI as-is. There are eight of them; one wrapper beats eight try blocks.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }
}
