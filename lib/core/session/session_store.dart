import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Where the signed-in session is kept between launches.
///
/// An interface rather than a direct `SharedPreferences` call so the widget
/// tests can run without a platform channel, and so moving to encrypted
/// storage later is a one-class change.
abstract interface class SessionStore {
  Future<Map<String, Object?>?> read();
  Future<void> write(Map<String, Object?> session);
  Future<void> clear();
}

/// Disk-backed store used by the live app.
///
/// `shared_preferences` is not encrypted. That is a deliberate, bounded risk:
/// the token it holds is the same one an attacker with the device unlocked
/// could obtain by simply opening the app. Move to `flutter_secure_storage` if
/// the token's lifetime is ever extended much past the current 30 days.
class PreferencesSessionStore implements SessionStore {
  const PreferencesSessionStore();

  static const String _key = 'auth_session';

  @override
  Future<Map<String, Object?>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    try {
      return jsonDecode(raw) as Map<String, Object?>;
    } catch (_) {
      // A value written by an older build that no longer parses. Dropping it
      // sends the user to the login screen, which is recoverable; throwing
      // here would fail the launch outright.
      await prefs.remove(_key);
      return null;
    }
  }

  @override
  Future<void> write(Map<String, Object?> session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Keeps the session for the lifetime of the process only. The default in the
/// fake object graph, so tests start signed out and leave nothing behind.
class InMemorySessionStore implements SessionStore {
  Map<String, Object?>? _session;

  @override
  Future<Map<String, Object?>?> read() async => _session;

  @override
  Future<void> write(Map<String, Object?> session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
