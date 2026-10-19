import '../repositories/admin_repository.dart';

/// Whether the signed-in user reviews registrations.
///
/// Read at startup to decide where the app opens, so it must never throw: a
/// failed lookup means "not an admin", which sends an ordinary user to their
/// ordinary screen rather than to an error.
class IsAdmin {
  const IsAdmin(this._repository);

  final AdminRepository _repository;

  Future<bool> call() async {
    try {
      return await _repository.isAdmin();
    } catch (_) {
      return false;
    }
  }
}
