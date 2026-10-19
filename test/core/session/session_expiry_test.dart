import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/core/network/api_client.dart';
import 'package:consultation_app/core/network/connectivity_monitor.dart';
import 'package:consultation_app/core/session/auth_session.dart';
import 'package:consultation_app/core/session/session_expiry.dart';
import 'package:consultation_app/core/session/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// What the API answers when the token names a user it cannot find, and when
/// no token was sent at all. Same status, same shape, different code.
final http.Response _ok = http.Response('{"ok":true}', 200);

String _refusal(String code) =>
    '{"error":{"code":"$code","message":"Please sign in again to continue."}}';

ApiClient _clientAlwaysRefusing(AuthSession session, SessionExpiry expiry) {
  return ApiClient(
    session,
    expiry,
    // Reached the server and was refused by it, which is the opposite of
    // offline — so the monitor here should never see an unreachable report.
    ConnectivityMonitor(httpClient: MockClient((_) async => _ok)),
    httpClient: MockClient(
      (request) async => http.Response(
        _refusal(
          request.headers.containsKey('authorization')
              ? 'session_invalid'
              : 'session_missing',
        ),
        401,
      ),
    ),
  );
}

Future<AuthSession> _signedIn(SessionExpiry expiry) async {
  final session = AuthSession(InMemorySessionStore(), expiry);
  await session.begin(
    userId: 'user-1',
    phone: '+919876543210',
    token: 'token-1',
    expiresIn: const Duration(days: 30),
  );
  return session;
}

void main() {
  group('SessionExpiry', () {
    test('one dead session is one expiry, however many requests find it', () {
      final expiry = SessionExpiry();
      var announcements = 0;
      expiry.addListener(() => announcements++);

      // A launch fires the admin check, the doctor application and the patient
      // profile at once, and a dead session fails all three.
      expiry.expire();
      expiry.expire();
      expiry.expire();

      expect(announcements, 1);
    });

    test('claiming the message does not re-arm the expiry', () {
      // The loop this prevents: reacting to an expiry means signing out, and
      // signing out is an API call carrying the same refused token, so it comes
      // back 401 from inside the handler. While claiming cleared the flag, that
      // second 401 announced a fresh expiry, which signed out again — an
      // unbounded loop that pushed a new landing screen on every pass and ended
      // in a crash.
      final expiry = SessionExpiry();
      var announcements = 0;
      expiry.addListener(() => announcements++);

      expiry.expire();
      expect(expiry.claim(), isTrue);

      expiry.expire();

      expect(announcements, 1);
      expect(expiry.claim(), isFalse, reason: 'the same expiry, told once');
    });

    test('signing in again re-arms it', () async {
      // Otherwise the latch above would be permanent, and the next genuine
      // expiry — hours later, on a session signed in since — would tell nobody.
      final expiry = SessionExpiry();
      expiry.expire();
      expiry.claim();

      await _signedIn(expiry);
      expect(expiry.isExpired, isFalse);

      var announcements = 0;
      expiry.addListener(() => announcements++);
      expiry.expire();

      expect(announcements, 1);
      expect(expiry.claim(), isTrue);
    });
  });

  group('ApiClient · a refused session', () {
    test('a 401 on a request that carried a token is an expiry', () async {
      final expiry = SessionExpiry();
      final client = _clientAlwaysRefusing(await _signedIn(expiry), expiry);

      await expectLater(
        client.get('/patients/me/exists'),
        throwsA(isA<Failure>()),
      );
      expect(expiry.isExpired, isTrue);
    });

    test('a 401 on a request that carried no token is not', () async {
      // It says nothing new — the user is signed out, which is already true.
      // Every call the sign-out path makes after clearing the token is one of
      // these, and treating them as news is what kept the loop turning.
      final expiry = SessionExpiry();
      final session = AuthSession(InMemorySessionStore(), expiry);
      final client = _clientAlwaysRefusing(session, expiry);

      await expectLater(
        client.get('/patients/me/exists'),
        throwsA(isA<Failure>()),
      );
      expect(expiry.isExpired, isFalse);
    });

    test('a probe cannot end the session on the caller\'s behalf', () async {
      // The admin check runs on every launch and straight after every sign-in,
      // ahead of the lookups that decide where the user goes. Its one caller
      // already reads any failure as "not an admin", so a route that refuses a
      // non-admin with a 401 must not sign that user out as a side effect.
      final expiry = SessionExpiry();
      final client = _clientAlwaysRefusing(await _signedIn(expiry), expiry);

      await expectLater(
        client.get('/admin/me', signalsExpiry: false),
        throwsA(isA<Failure>()),
      );
      expect(expiry.isExpired, isFalse);
    });

    test('the failure still reaches the caller either way', () async {
      final expiry = SessionExpiry();
      final session = AuthSession(InMemorySessionStore(), expiry);
      final client = _clientAlwaysRefusing(session, expiry);

      await expectLater(
        client.get('/patients/me/exists'),
        throwsA(
          isA<Failure>().having(
            (failure) => failure.isSessionExpired,
            'isSessionExpired',
            isTrue,
          ),
        ),
      );
    });
  });
}
