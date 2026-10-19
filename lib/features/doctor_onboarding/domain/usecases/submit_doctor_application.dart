import '../../../../core/error/failure.dart';
import '../entities/bank_account.dart';
import '../entities/doctor_application.dart';
import '../entities/doctor_credentials.dart';
import '../entities/medical_certificate.dart';
import '../repositories/doctor_onboarding_repository.dart';

/// Files a doctor's registration for review.
class SubmitDoctorApplication {
  const SubmitDoctorApplication(this._repository);

  final DoctorOnboardingRepository _repository;

  /// Both halves of the form are checked here, so an incomplete registration
  /// cannot be submitted from anywhere.
  Future<DoctorApplication> call({
    required DoctorCredentials credentials,
    required BankAccount bankAccount,
    required MedicalCertificate certificate,
  }) {
    // `Failure`, not `ArgumentError`. Controllers catch `Failure` for its
    // message and everything else for the generic one, so an `ArgumentError`
    // with a perfectly good explanation inside it arrived as "Something went
    // wrong".
    if (!certificate.isAcceptable) {
      throw Failure(
        certificate.rejectionReason ??
            'That certificate could not be used. Upload a PDF, JPG or PNG.',
      );
    }
    if (!credentials.isComplete) {
      throw const Failure('Your professional details are incomplete.');
    }
    if (!bankAccount.isComplete) {
      throw const Failure('Your payout details are incomplete.');
    }

    return _repository.submitApplication(
      credentials: credentials,
      bankAccount: bankAccount,
      certificate: certificate,
    );
  }
}
