import '../repositories/profile_repository.dart';

/// Whether the signed-in patient already has a stored record.
///
/// Asked straight after OTP verification, where sign-in is a given and the only
/// open question is whether this person has been here before.
class HasPatientProfile {
  const HasPatientProfile(this._repository);

  final ProfileRepository _repository;

  Future<bool> call() async {
    try {
      return await _repository.hasProfile();
    } catch (_) {
      // Undecidable, so take the recoverable branch: re-entering the form
      // overwrites the record with the same values, whereas a patient sent to a
      // dashboard that has no record to load is stuck there.
      return false;
    }
  }
}
