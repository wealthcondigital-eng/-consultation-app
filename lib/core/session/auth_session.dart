import '../logging/auth_logger.dart';
import 'session_expiry.dart';
import 'session_store.dart';

/// The signed-in user, as the app knows them between launches.
///
/// Readable *synchronously*, which is the property that matters: startup
/// branches on it before the first frame. [restore] is what makes that true —
/// it is awaited once in `main()`, and every read after that is in memory.
class AuthSession {
  AuthSession(this._store, this._expiry);

  final SessionStore _store;

  /// Cleared by [begin]. A session that has just been issued cannot be the one
  /// the server refused a moment ago, and leaving the old verdict standing
  /// would mean the *next* real expiry was never announced.
  final SessionExpiry _expiry;

  _Session? _current;

  /// True once a code has been verified, and on every later launch until the
  /// token expires or the user signs out.
  bool get isSignedIn => _current != null;

  /// The Mongo `_id` of the user document. The identifier every other
  /// collection keys against.
  String? get userId => _current?.userId;

  /// E.164, e.g. `+919876543210`.
  String? get phone => _current?.phone;

  /// The bearer token for the consultation API, or null when signed out.
  String? get token => _current?.token;

  /// Loads the stored session. Called once from `main()` before `runApp`.
  ///
  /// An expired token is discarded here rather than being allowed to fail on
  /// the first request, so the user lands on the login screen instead of on a
  /// home screen that cannot load anything.
  Future<void> restore() async {
    final stored = await _store.read();

    if (stored == null) {
      AuthLogger.event('SESSION · nothing stored (signed out)');
      return;
    }

    final session = _Session.fromJson(stored);

    if (session == null || session.hasExpired) {
      await _store.clear();
      AuthLogger.event('SESSION · stored session discarded', {
        'reason': session == null ? 'unreadable' : 'expired',
      });
      return;
    }

    _current = session;
    AuthLogger.event('SESSION · restored', {
      'userId': session.userId,
      'phone': session.phone,
      'expires': session.expiresAt.toLocal().toString(),
    });
  }

  /// Records a freshly verified sign-in.
  Future<void> begin({
    required String userId,
    required String phone,
    required String token,
    required Duration expiresIn,
  }) async {
    final session = _Session(
      userId: userId,
      phone: phone,
      token: token,
      expiresAt: DateTime.now().toUtc().add(expiresIn),
    );

    _current = session;
    _expiry.reset();
    await _store.write(session.toJson());

    AuthLogger.event('SESSION · started', {
      'userId': userId,
      'phone': phone,
      'expires': session.expiresAt.toLocal().toString(),
    });
    AuthLogger.token('after OTP sign-in', token);
  }

  /// Ends the session. Safe to call when there is none.
  Future<void> end() async {
    AuthLogger.event('SESSION · ending', {'userId': _current?.userId});
    _current = null;
    await _store.clear();
  }

  /// The id, or a [Failure]-worthy null for callers that cannot proceed
  /// without one. Kept here so every data source words it the same way.
  String requireUserId() {
    final id = userId;
    if (id == null) {
      throw StateError('No signed-in user. Call this behind an auth guard.');
    }
    return id;
  }
}

class _Session {
  const _Session({
    required this.userId,
    required this.phone,
    required this.token,
    required this.expiresAt,
  });

  final String userId;
  final String phone;
  final String token;
  final DateTime expiresAt;

  /// Treated as expired a minute early, so a request is never sent with a
  /// token that dies in flight.
  bool get hasExpired => DateTime.now().toUtc().isAfter(
    expiresAt.subtract(const Duration(minutes: 1)),
  );

  Map<String, Object?> toJson() => {
    'userId': userId,
    'phone': phone,
    'token': token,
    'expiresAt': expiresAt.toIso8601String(),
  };

  /// Null when the stored map is missing a field or holds the wrong type —
  /// which is what a format change between builds looks like.
  static _Session? fromJson(Map<String, Object?> json) {
    final userId = json['userId'];
    final phone = json['phone'];
    final token = json['token'];
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '')?.toLocal();

    if (userId is! String || phone is! String || token is! String) return null;
    if (expiresAt == null) return null;

    return _Session(
      userId: userId,
      phone: phone,
      token: token,
      expiresAt: expiresAt,
    );
  }
}
