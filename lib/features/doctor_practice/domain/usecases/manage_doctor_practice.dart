import '../../../../core/error/failure.dart';
import '../../../doctor_onboarding/domain/entities/bank_account.dart';
import '../../../doctor_onboarding/domain/entities/medical_certificate.dart';
import '../entities/doctor_credential.dart';
import '../entities/doctor_earnings.dart';
import '../entities/doctor_patient.dart';
import '../entities/doctor_patient_detail.dart';
import '../entities/doctor_review.dart';
import '../entities/doctor_practice_profile.dart';
import '../entities/doctor_settings.dart';
import '../repositories/doctor_practice_repository.dart';

/// The doctor's own profile: read it, edit it, and change the photo on it.
class ManageDoctorProfile {
  const ManageDoctorProfile(this._repository);

  final DoctorPracticeRepository _repository;

  Future<DoctorPracticeProfile> load() => _repository.fetchProfile();

  /// Saves the doctor's edits.
  ///
  /// The screen disables Save long before this; the guard keeps a bad record
  /// out of the database regardless of what the UI allows — the same shape
  /// `UpdatePatientDetails` takes.
  Future<DoctorPracticeProfile> save(DoctorProfileEdits edits) {
    if (!edits.isValid) {
      throw const Failure('Check the highlighted fields and try again.');
    }

    return _repository.updateProfile(edits);
  }

  Future<String?> uploadPhoto(String filePath) =>
      _repository.uploadPhoto(filePath);

  Future<String?> removePhoto() => _repository.removePhoto();
}

/// Who this doctor has consulted.
class GetDoctorPatients {
  const GetDoctorPatients(this._repository);

  final DoctorPracticeRepository _repository;

  Future<List<DoctorPatient>> call({String? search, int limit = 50}) =>
      _repository.fetchPatients(search: search, limit: limit);
}

/// One patient, and every consultation this doctor has had with them.
///
/// Opened from a card on the schedule, so the doctor can see who they are
/// about to call before they call them — which used to mean tapping through to
/// the Patients tab and finding the name by hand, mid-appointment.
class GetPatientDetail {
  const GetPatientDetail(this._repository);

  final DoctorPracticeRepository _repository;

  Future<DoctorPatientDetail> call(String patientId) =>
      _repository.fetchPatientDetail(patientId);
}

/// What patients wrote about this doctor, named — see [DoctorReview].
class GetDoctorReviews {
  const GetDoctorReviews(this._repository);

  final DoctorPracticeRepository _repository;

  Future<List<DoctorReview>> call({int limit = 50}) =>
      _repository.fetchReviews(limit: limit);
}

/// What the doctor has earned.

class GetDoctorEarnings {
  const GetDoctorEarnings(this._repository);

  final DoctorPracticeRepository _repository;

  Future<DoctorEarnings> call(EarningsPeriod period) =>
      _repository.fetchEarnings(period);
}

/// Where the doctor is paid: read it back masked, or replace it.
class ManageBankAccount {
  const ManageBankAccount(this._repository);

  final DoctorPracticeRepository _repository;

  Future<BankAccountSummary> load() => _repository.fetchBankAccount();

  /// Replaces the payout destination.
  ///
  /// Validated here as well as on the form, because this is where money starts
  /// going somewhere: a nine-digit typo in an account number is a payment to a
  /// stranger, and the API checking it too is the third line of the same
  /// defence rather than a duplication.
  Future<BankAccountSummary> save(BankAccount account) {
    if (!account.isComplete) {
      throw const Failure('Check your account details and try again.');
    }

    return _repository.saveBankAccount(account);
  }
}

/// The paperwork behind the registration, what review made of it, and the
/// certificates the doctor adds to their own profile afterwards.
class GetDoctorCredentials {
  const GetDoctorCredentials(this._repository);

  final DoctorPracticeRepository _repository;

  /// The shortest title that is any use to a patient reading it on a profile.
  /// `MD` is two characters and is a real answer, so this is deliberately low —
  /// it is here to refuse an empty box, not to judge a qualification.
  static const int minTitleLength = 2;

  Future<List<DoctorCredential>> call() => _repository.fetchCredentials();

  /// Adds a certificate, awaiting review.
  ///
  /// The title is what patients read once a reviewer accepts it — the file
  /// itself never leaves the private bucket — so a blank one is refused here
  /// rather than filed as an untitled claim nobody can act on.
  ///
  /// Throws [Failure] rather than `ArgumentError`: controllers catch `Failure`
  /// for its message and everything else for the generic one, so an
  /// `ArgumentError` with a perfectly good explanation inside it arrives as
  /// "Something went wrong".
  Future<DoctorCredential> add({
    required String title,
    required MedicalCertificate certificate,
  }) {
    final named = title.trim();

    if (named.length < minTitleLength) {
      throw const Failure(
        'Give the certificate a name patients will recognise.',
      );
    }

    if (certificate.rejectionReason case final reason?) {
      throw Failure(reason);
    }

    final path = certificate.localPath;
    if (path == null || path.isEmpty) {
      throw const Failure('That file could not be read. Pick it again.');
    }

    return _repository.addCertificate(
      title: named,
      filePath: path,
      contentType: certificate.mimeType,
    );
  }

  Future<void> remove(DoctorCredential credential) {
    if (!credential.isRemovable) {
      // Refused in the app as well as on the API. The registration's paperwork
      // is what the approval rests on, and an approved account with nothing
      // behind it is the outcome the review exists to prevent.
      throw const Failure(
        'Documents filed with your registration cannot be removed.',
      );
    }

    return _repository.removeCertificate(credential.id);
  }
}

/// The doctor's notification preferences: read them, and flip one.
class ManageDoctorSettings {
  const ManageDoctorSettings(this._repository);

  final DoctorPracticeRepository _repository;

  Future<DoctorSettings> load() => _repository.fetchSettings();

  Future<DoctorSettings> set(DoctorNotificationToggle toggle, bool value) =>
      _repository.setNotificationPreference(toggle, value);
}
