import 'package:consultation_app/features/onboarding/data/datasources/role_local_data_source.dart';
import 'package:consultation_app/features/onboarding/data/repositories/role_repository_impl.dart';
import 'package:consultation_app/features/onboarding/domain/entities/user_role.dart';
import 'package:consultation_app/features/onboarding/domain/usecases/get_selected_role.dart';
import 'package:consultation_app/features/onboarding/domain/usecases/select_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RoleRepositoryImpl repository;

  setUp(() {
    repository = RoleRepositoryImpl(InMemoryRoleLocalDataSource());
  });

  test('reads back nothing before a role is chosen', () async {
    expect(await GetSelectedRole(repository)(), isNull);
  });

  test('round-trips the chosen role', () async {
    await SelectRole(repository)(UserRole.doctor);

    expect(await GetSelectedRole(repository)(), UserRole.doctor);
  });

  test('clearing forgets the role', () async {
    await SelectRole(repository)(UserRole.patient);
    await repository.clearSelectedRole();

    expect(await GetSelectedRole(repository)(), isNull);
  });

  test('maps unknown persisted keys to null rather than throwing', () {
    expect(UserRole.fromKey('nurse'), isNull);
    expect(UserRole.fromKey(null), isNull);
  });
}
