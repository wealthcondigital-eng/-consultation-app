import '../entities/user_role.dart';

/// Contract the presentation layer depends on. The concrete implementation
/// lives in the data layer and can be swapped without touching the UI.
abstract interface class RoleRepository {
  /// The role chosen on a previous launch, or null on first run.
  Future<UserRole?> readSelectedRole();

  /// Remembers the user's choice so onboarding can be skipped next time.
  Future<void> saveSelectedRole(UserRole role);

  /// Clears the choice — used by sign-out.
  Future<void> clearSelectedRole();
}
