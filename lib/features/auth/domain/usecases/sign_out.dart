import '../repositories/auth_repository.dart';

/// Ends the patient's session.
class SignOut {
  const SignOut(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}
