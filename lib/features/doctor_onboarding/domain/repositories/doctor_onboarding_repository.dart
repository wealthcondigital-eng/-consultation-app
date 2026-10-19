import '../entities/bank_account.dart';
import '../entities/doctor_application.dart';
import '../entities/doctor_availability.dart';
import '../entities/doctor_credentials.dart';
import '../entities/doctor_setup_options.dart';
import '../entities/medical_certificate.dart';
import '../entities/practice_setup.dart';

/// Contract for taking a doctor from sign-up to consulting.
abstract interface class DoctorOnboardingRepository {
  /// What the setup form's dropdowns offer.
  Future<DoctorSetupOptions> fetchSetupOptions();

  /// Reads the certificate and returns whatever it could fill in.
  Future<DoctorCredentials> parseCertificate(MedicalCertificate certificate);

  /// Files the registration for review.
  Future<DoctorApplication> submitApplication({
    required DoctorCredentials credentials,
    required BankAccount bankAccount,
    MedicalCertificate? certificate,
  });

  /// The signed-in doctor's own registration, or null when there is none.
  Future<DoctorApplication?> fetchMyApplication();

  /// Follows the review, ending on approval or rejection.
  Stream<DoctorApplication> watchApplication(String applicationId);

  /// The practice wizard's state: fee choices and how far along it is.
  Future<PracticeSetup> fetchPracticeSetup();

  /// Sets one or both consultation fees.
  ///
  /// Either may be null, meaning "leave that one alone" — a voice call is
  /// priced separately from a video one, and a screen editing one row must not
  /// have to restate the other.
  Future<void> saveConsultationFees({int? videoFee, int? audioFee});

  /// The doctor's availability, empty on a first visit.
  Future<DoctorAvailability> fetchAvailability();

  Future<void> saveAvailability(DoctorAvailability availability);
}
