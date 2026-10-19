import '../entities/medical_history.dart';
import '../entities/medical_report.dart';
import '../entities/notification_settings.dart';
import '../entities/patient_account.dart';
import '../entities/patient_details.dart';
import '../entities/patient_profile.dart';

/// Contract for storing and reading the patient's profile.
abstract interface class ProfileRepository {
  /// Persists [profile], throwing a `Failure` if it cannot be saved.
  Future<void> savePatientProfile(PatientProfile profile);

  /// The signed-in patient's stored account.
  Future<PatientAccount> fetchAccount();

  /// Applies the patient's own edits to their stored record.
  ///
  /// Answers the record as the server stored it, or null when the backend
  /// did not send one back — the caller then re-reads it.
  Future<PatientAccount?> updateDetails(PatientDetails details);

  /// Whether a row exists for the signed-in patient, without fetching it.
  /// Used at startup to tell a returning patient from one who never finished
  /// onboarding.
  Future<bool> hasProfile();

  /// The patient's own account of their health.
  Future<MedicalHistory> fetchMedicalHistory();

  /// Replaces it, and answers with what was actually stored — including the
  /// timestamp the server stamped, which the summary line quotes.
  Future<MedicalHistory> saveMedicalHistory(MedicalHistory history);

  Future<NotificationSettings> fetchSettings();

  /// Flips one preference. One at a time rather than a whole object, so a
  /// screen that has been open a while cannot undo a change made elsewhere.
  Future<NotificationSettings> setNotificationPreference(
    PatientNotificationToggle toggle,
    bool value,
  );

  /// Uploads a new profile photo and answers with the path it is served from.
  Future<String?> uploadPhoto(String filePath);

  Future<String?> removePhoto();

  /// Erases the account. Answers with when the number may sign up again.
  Future<DateTime?> deleteAccount();

  Future<List<MedicalReport>> fetchReports();

  Future<MedicalReport> uploadReport({
    required String filePath,
    required String title,
    MedicalRecordKind kind = MedicalRecordKind.report,
  });

  Future<void> deleteReport(String id);
}
