import '../../../../core/error/failure.dart';
import '../../../../core/session/auth_session.dart';
import '../../domain/entities/otp_challenge.dart';

/// Talks to whatever backend issues the OTP.
abstract interface class AuthRemoteDataSource {
  /// Whether a session is already open, restored from disk at launch.
  bool get isSignedIn;

  /// Texts a code to [e164PhoneNumber] and returns the challenge the OTP screen
  /// quotes back when confirming it — the verification id, and how long the
  /// server wants to be left alone before another is asked for.
  Future<OtpChallenge> sendOtp(String e164PhoneNumber);

  /// Confirms [code] and opens the session.
  Future<void> confirmOtp(String verificationId, String code, {String? role});

  /// Ends the session and discards its credentials.
  Future<void> signOut();
}

/// Stand-in used by the tests and the fake object graph.
class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  const FakeAuthRemoteDataSource([this._session]);

  final AuthSession? _session;

  static const _latency = Duration(milliseconds: 600);

  @override
  bool get isSignedIn => _session?.isSignedIn ?? false;

  @override
  Future<OtpChallenge> sendOtp(String e164PhoneNumber) async {
    await Future<void>.delayed(_latency);
    return OtpChallenge(
      verificationId: 'verification-${e164PhoneNumber.hashCode}',
      resendAfter: const Duration(seconds: 30),
    );
  }

  /// The stub accepts any code except this one, so the failure path stays
  /// exercisable in development and tests.
  static const rejectedCode = '0000';

  @override
  Future<void> confirmOtp(
    String verificationId,
    String code, {
    String? role,
  }) async {
    await Future<void>.delayed(_latency);
    if (code == rejectedCode) {
      throw const Failure('That code is incorrect. Please try again.');
    }
    await _session?.begin(
      userId: 'user-${verificationId.hashCode}',
      phone: '+919876543210',
      token: 'fake-jwt-token',
      expiresIn: const Duration(days: 30),
    );
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _session?.end();
  }
}
