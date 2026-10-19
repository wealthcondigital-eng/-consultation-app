import '../../domain/entities/user_role.dart';
import '../../domain/repositories/role_repository.dart';
import '../datasources/role_local_data_source.dart';

class RoleRepositoryImpl implements RoleRepository {
  const RoleRepositoryImpl(this._localDataSource);

  final RoleLocalDataSource _localDataSource;

  @override
  Future<UserRole?> readSelectedRole() async {
    return UserRole.fromKey(await _localDataSource.readRoleKey());
  }

  @override
  Future<void> saveSelectedRole(UserRole role) {
    return _localDataSource.writeRoleKey(role.key);
  }

  @override
  Future<void> clearSelectedRole() => _localDataSource.deleteRoleKey();
}
