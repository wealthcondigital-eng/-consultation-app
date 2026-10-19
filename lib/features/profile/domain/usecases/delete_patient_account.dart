import '../repositories/profile_repository.dart';

/// Erases the account for good.
///
/// Its own use case rather than a method on a settings one, because it is not a
/// setting: it ends the session, it cannot be undone, and the screen that calls
/// it has to sign the user out afterwards whatever else happens.
///
/// Answers with the moment the number may open a new account — a day out. The
/// screen shows it, because somebody who changes their mind an hour later
/// otherwise meets a refusal at the login screen with no explanation attached.
class DeletePatientAccount {
  const DeletePatientAccount(this._repository);

  final ProfileRepository _repository;

  Future<DateTime?> call() => _repository.deleteAccount();
}
