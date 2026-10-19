import '../../../../core/error/failure.dart';
import '../entities/doctor_credentials.dart';
import '../entities/medical_certificate.dart';
import '../repositories/doctor_onboarding_repository.dart';

/// Reads a certificate and pre-fills the profile from it.
class ParseMedicalCertificate {
  const ParseMedicalCertificate(this._repository);

  final DoctorOnboardingRepository _repository;

  /// Rejects a file the upload rules do not allow before it is sent anywhere.
  Future<DoctorCredentials> call(MedicalCertificate certificate) {
    final reason = certificate.rejectionReason;
    if (reason != null) throw Failure(reason);

    return _repository.parseCertificate(certificate);
  }
}
