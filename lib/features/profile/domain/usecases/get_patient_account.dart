import '../entities/patient_account.dart';
import '../repositories/profile_repository.dart';

/// Loads the account shown on My Profile.
class GetPatientAccount {
  const GetPatientAccount(this._repository);

  final ProfileRepository _repository;

  Future<PatientAccount> call() => _repository.fetchAccount();
}
