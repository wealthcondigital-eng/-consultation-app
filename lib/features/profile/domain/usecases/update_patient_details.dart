import '../../../../core/error/failure.dart';
import '../entities/patient_account.dart';
import '../entities/patient_details.dart';
import '../repositories/profile_repository.dart';

/// Saves the patient's edits to their own record.
class UpdatePatientDetails {
  const UpdatePatientDetails(this._repository);

  final ProfileRepository _repository;

  Future<PatientAccount?> call(PatientDetails details, {DateTime? now}) {
    // The screen disables saving long before this; the guard keeps a bad record
    // out of the database regardless of what the UI allows.
    if (!details.isComplete(now ?? DateTime.now())) {
      throw const Failure('Check the highlighted fields and try again.');
    }
    return _repository.updateDetails(details);
  }
}
