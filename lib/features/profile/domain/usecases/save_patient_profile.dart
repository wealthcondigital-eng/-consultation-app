import '../../../../core/error/failure.dart';
import '../entities/patient_profile.dart';
import '../repositories/profile_repository.dart';

/// Stores the patient's profile once every required field is present.
class SavePatientProfile {
  const SavePatientProfile(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ProfileRepository _repository;
  final DateTime Function() _clock;

  Future<void> call(PatientProfile profile) {
    // A last line of defence: the screen disables submission long before this,
    // but consent and the 18+ rule are legal requirements and must not depend
    // on the UI. `isComplete` covers both, so a minor's details cannot reach
    // the repository even if the form is bypassed.
    if (!profile.isComplete(_clock())) {
      throw const Failure('Complete every field before continuing.');
    }
    return _repository.savePatientProfile(profile);
  }
}
