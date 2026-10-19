import '../../../doctor_onboarding/domain/entities/bank_account.dart';
import '../entities/doctor_credential.dart';
import '../entities/doctor_earnings.dart';
import '../entities/doctor_patient.dart';
import '../entities/doctor_patient_detail.dart';
import '../entities/doctor_review.dart';
import '../entities/doctor_practice_profile.dart';
import '../entities/doctor_settings.dart';

/// Contract for everything a doctor manages about their practice.
///
/// Distinct from `DoctorOnboardingRepository`, which is the registration and
/// the review. This is what a doctor changes *after* they are approved: how to
/// reach them, who they have seen, what they have earned, where it is paid.
abstract interface class DoctorPracticeRepository {
  Future<DoctorPracticeProfile> fetchProfile();

  /// Applies the doctor's own edits and answers with the stored profile.
  Future<DoctorPracticeProfile> updateProfile(DoctorProfileEdits edits);

  Future<String?> uploadPhoto(String filePath);

  Future<String?> removePhoto();

  Future<List<DoctorPatient>> fetchPatients({String? search, int limit});

  Future<DoctorPatientDetail> fetchPatientDetail(String patientId);

  Future<List<DoctorReview>> fetchReviews({int limit});

  Future<DoctorEarnings> fetchEarnings(EarningsPeriod period);

  Future<BankAccountSummary> fetchBankAccount();

  Future<BankAccountSummary> saveBankAccount(BankAccount account);

  Future<List<DoctorCredential>> fetchCredentials();

  /// Adds a certificate to the doctor's own profile, awaiting review.
  Future<DoctorCredential> addCertificate({
    required String title,
    required String filePath,
    required String contentType,
  });

  /// Withdraws one the doctor added. Not the registration's own paperwork —
  /// the approval rests on that.
  Future<void> removeCertificate(String id);

  Future<DoctorSettings> fetchSettings();

  /// Flips one preference. One at a time rather than a whole object, so a
  /// screen that has been open a while cannot undo a change made elsewhere.
  Future<DoctorSettings> setNotificationPreference(
    DoctorNotificationToggle toggle,
    bool value,
  );
}
