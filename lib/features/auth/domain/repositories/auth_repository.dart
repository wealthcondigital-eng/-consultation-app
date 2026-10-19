import '../entities/otp_challenge.dart';
import '../entities/otp_code.dart';
import '../entities/phone_number.dart';

/// Contract for starting an authentication session.
///
/// Implementations throw a `Failure` on error rather than returning one, which
/// keeps the happy path in the controller readable.
abstract interface class AuthRepository {
  /// Whether a session was restored from a previous launch. Synchronous: the
  /// session is read from disk once at startup, so this costs no network call.
  bool get isSignedIn;

  /// Sends a one-time password to [phoneNumber] and returns the challenge the
  /// OTP screen will need to confirm it — its id, and the resend cooldown.
  Future<OtpChallenge> requestOtp(PhoneNumber phoneNumber);

  /// Confirms [code] against the session started by [requestOtp].
  Future<void> verifyOtp({
    required String verificationId,
    required OtpCode code,
    String? role,
  });

  /// Ends the session. Safe to call whether or not one is open.
  Future<void> signOut();
}
