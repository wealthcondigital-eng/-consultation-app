import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for the onboarding role.
abstract interface class RoleLocalDataSource {
  Future<String?> readRoleKey();
  Future<void> writeRoleKey(String key);
  Future<void> deleteRoleKey();
}

/// The role, kept across launches.
///
/// It has to survive a restart, and for a long time it did not: the only
/// implementation was [InMemoryRoleLocalDataSource], so on every cold launch
/// the app had forgotten which journey the person was in. A doctor whose
/// record lookup was slow, or who simply had a patient row as well, was handed
/// the patient dashboard — the role that decided it had evaporated with the
/// process.
class PreferencesRoleLocalDataSource implements RoleLocalDataSource {
  const PreferencesRoleLocalDataSource();

  static const String _key = 'onboarding_role';

  @override
  Future<String?> readRoleKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> writeRoleKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, key);
  }

  @override
  Future<void> deleteRoleKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// In-memory stand-in, for the widget tests and the offline demo build, where
/// there is no platform channel to store anything on.
class InMemoryRoleLocalDataSource implements RoleLocalDataSource {
  String? _roleKey;

  @override
  Future<String?> readRoleKey() async => _roleKey;

  @override
  Future<void> writeRoleKey(String key) async => _roleKey = key;

  @override
  Future<void> deleteRoleKey() async => _roleKey = null;
}
