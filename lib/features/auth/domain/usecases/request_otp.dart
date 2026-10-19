import '../../../../core/error/failure.dart';
import '../../../../core/l10n/tr.dart';
import '../entities/otp_challenge.dart';
import '../entities/phone_number.dart';
import '../repositories/auth_repository.dart';

/// Sends a login code to the number the user entered.
class RequestOtp {
  const RequestOtp(this._repository);

  final AuthRepository _repository;

  /// Returns the challenge for the OTP screen: the verification id, and the
  /// cooldown the server wants observed before another code is asked for.
  Future<OtpChallenge> call(PhoneNumber phoneNumber) {
    if (!phoneNumber.isValid) {
      throw Failure(
        tr('Enter a valid {count}-digit number.', {
          'count': phoneNumber.country.digitCount,
        }),
      );
    }
    return _repository.requestOtp(phoneNumber);
  }
}
