import '../entities/user_role.dart';
import '../repositories/role_repository.dart';

/// Reads back a previously chosen role, if there is one.
class GetSelectedRole {
  const GetSelectedRole(this._repository);

  final RoleRepository _repository;

  Future<UserRole?> call() => _repository.readSelectedRole();
}
