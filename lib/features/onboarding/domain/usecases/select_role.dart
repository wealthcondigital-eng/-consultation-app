import '../entities/user_role.dart';
import '../repositories/role_repository.dart';

/// Records the role the user picked on the landing screen.
class SelectRole {
  const SelectRole(this._repository);

  final RoleRepository _repository;

  Future<void> call(UserRole role) => _repository.saveSelectedRole(role);
}
