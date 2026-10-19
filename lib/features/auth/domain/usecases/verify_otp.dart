import '../../../../core/error/failure.dart';
import '../../../../core/l10n/tr.dart';
import '../entities/otp_code.dart';
import '../repositories/auth_repository.dart';

/// Confirms the code the user typed against the OTP session.
class VerifyOtp {
  const VerifyOtp(this._repository);

  final AuthRepository _repository;

  Future<void> call({
    required String verificationId,
    required OtpCode code,
    String? role,
  }) {
    if (!code.isComplete) {
      throw Failure(
        tr('Enter the {count}-digit code.', {'count': OtpCode.length}),
      );
    }
    return _repository.verifyOtp(
      verificationId: verificationId,
      code: code,
      role: role,
    );
  }
}
