/// The one-time password as the user is entering it.
class OtpCode {
  const OtpCode(this.digits);

  const OtpCode.empty() : digits = '';

  /// How many digits the backend issues. Drives the number of input boxes and
  /// the completeness check, so changing it here changes both.
  ///
  /// Must stay in step with `OTP_LENGTH` in `server/.env`, which in turn has to
  /// fit the DLT-approved template the SMS gateway sends.
  static const int length = 4;

  /// Digits only, never longer than [length].
  final String digits;

  bool get isComplete => digits.length == length;

  bool get isEmpty => digits.isEmpty;

  @override
  bool operator ==(Object other) => other is OtpCode && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;
}
