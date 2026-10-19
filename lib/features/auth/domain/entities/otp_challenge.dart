/// What the server answered when a code was requested.
///
/// This used to be a bare verification id, and the cooldown the OTP screen
/// counted down was a constant compiled into the app. That is the bug behind
/// "too many requests, even after reinstalling": the server throttles per phone
/// number, not per install, so a 30-second local timer against a 60-second
/// server window let the user ask again at the exact moment that was guaranteed
/// to be refused — and on most SMS gateways a refused send still counts against
/// the window, so the lockout renewed itself every time.
///
/// The server's own number travels with the id now, and the screen counts that
/// down instead.
class OtpChallenge {
  const OtpChallenge({
    required this.verificationId,
    this.resendAfter,
    this.code,
  });

  /// Quoted back when the code is confirmed.
  final String verificationId;

  /// Optional OTP code for auto-fill in development/test or SMS auto-retrieval.
  final String? code;

  /// How long before another code may be asked for. Null when the server did
  /// not say, in which case the caller falls back to [defaultResendCooldown].
  final Duration? resendAfter;

  /// Used only when the server sends no cooldown of its own. Deliberately
  /// longer than the old 30 seconds: erring towards waiting costs one extra
  /// half-minute, and erring the other way costs the account its next hour.
  static const Duration defaultResendCooldown = Duration(seconds: 60);

  /// What the resend timer should actually run for.
  Duration get cooldown => resendAfter ?? defaultResendCooldown;
}
