import 'dart:async';

import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/logging/auth_logger.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/push/push_service.dart';
import '../../../../core/session/auth_session.dart';
import '../../domain/entities/otp_challenge.dart';
import 'auth_remote_data_source.dart';

/// OTP login against the consultation API in `server/`.
///
/// The code is generated, texted and checked by the server; the app never sees
/// it and never holds an SMS gateway key. What comes back from a successful
/// check is a bearer token and the user's Mongo id, which [AuthSession] stores
/// and every later request carries.
class OtpAuthRemoteDataSource implements AuthRemoteDataSource {
  const OtpAuthRemoteDataSource(this._client, this._session);

  final ApiClient _client;
  final AuthSession _session;

  /// Read straight out of the restored session — no network call, which is
  /// what lets startup branch on it before the first frame.
  @override
  bool get isSignedIn => _session.isSignedIn;

  @override
  Future<OtpChallenge> sendOtp(String e164PhoneNumber) async {
    AuthLogger.event('AUTH · OTP requested', {
      'phone': e164PhoneNumber,
      'already signed in': isSignedIn,
    });

    final json = await _client.post(
      '/auth/otp/request',
      body: {'phone': e164PhoneNumber},
    );

    final verificationId = json['verificationId'];
    if (verificationId is! String || verificationId.isEmpty) {
      throw const Failure.unexpected();
    }

    // The server's own cooldown, carried out rather than dropped. A local timer
    // shorter than the server's window is what brought the Resend button back
    // to life at the exact moment the next request was certain to be refused —
    // and on most SMS gateways a refused send still counts against the window,
    // so retrying is what kept the lockout alive across reinstalls.
    final resendSeconds = json['resendAfterSeconds'];

    AuthLogger.event('AUTH · SMS sent', {
      'phone': e164PhoneNumber,
      'verificationId': verificationId,
      'expires': json['expiresAt'],
      'resend after': '${resendSeconds}s',
    });

    final code = json['code'] as String? ?? json['otp'] as String?;

    return OtpChallenge(
      verificationId: verificationId,
      code: code,
      resendAfter: resendSeconds is num && resendSeconds > 0
          ? Duration(seconds: resendSeconds.toInt())
          : null,
    );
  }

  @override
  Future<void> confirmOtp(
    String verificationId,
    String code, {
    String? role,
  }) async {
    final Map<String, Object?> eventDetails = {
      'verificationId': verificationId,
      'code length': code.length,
    };
    if (role != null) {
      eventDetails['role'] = role;
    }
    AuthLogger.event('AUTH · verifying code', eventDetails);

    final Map<String, Object?> body = {
      'verificationId': verificationId,
      'code': code,
    };
    if (role != null) {
      body['role'] = role;
    }

    final json = await _client.post('/auth/otp/verify', body: body);

    final token = json['token'];
    final expiresInSeconds = json['expiresInSeconds'];
    final user = json['user'];

    // A 200 that does not carry a usable session is a server bug, not a wrong
    // code — but the user would be stranded either way, so it fails here
    // rather than leaving the app "signed in" with nothing to sign requests.
    if (token is! String ||
        user is! Map ||
        user['id'] is! String ||
        user['phone'] is! String) {
      throw const Failure.unexpected();
    }

    final num? rawExpires = expiresInSeconds is num ? expiresInSeconds : null;
    final int expiryInSec = (rawExpires != null && rawExpires > 0)
        ? rawExpires.toInt()
        : 30 * 24 * 3600; // 30 days default fallback

    await _session.begin(
      userId: user['id'] as String,
      phone: user['phone'] as String,
      token: token,
      expiresIn: Duration(seconds: expiryInSec),
    );

    // The handset can be rung from now on. Registered here rather than at
    // launch because the token is filed against a user, and before this line
    // there was no user to file it against.
    unawaited(sl<PushService>().registerDevice());

    AuthLogger.event('AUTH · signed in with phone', {
      'userId': user['id'],
      'phone': user['phone'],
      'new account': json['isNewUser'],
    });
  }

  @override
  Future<void> signOut() async {
    AuthLogger.event('AUTH · signing out', {'userId': _session.userId});

    try {
      // Best-effort: the token is stateless, so the local clear below is what
      // actually ends the session. A failure here must not leave the user
      // stuck signed in on a device they are trying to sign out of.
      await _client.post('/auth/signout');
    } on Failure catch (failure) {
      AuthLogger.event('AUTH · sign-out call failed (clearing anyway)', {
        'reason': failure.message,
      });
    }

    await sl<PushService>().unregisterDevice();
    await _session.end();

    AuthLogger.event('AUTH · signed out', {
      'session now': _session.isSignedIn ? 'still open (bug)' : 'cleared',
    });
  }
}
