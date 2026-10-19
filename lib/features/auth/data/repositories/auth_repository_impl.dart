import '../../../../core/error/failure.dart';
import '../../domain/entities/otp_challenge.dart';
import '../../domain/entities/otp_code.dart';
import '../../domain/entities/phone_number.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  bool get isSignedIn => _remoteDataSource.isSignedIn;

  @override
  Future<OtpChallenge> requestOtp(PhoneNumber phoneNumber) async {
    try {
      return await _remoteDataSource.sendOtp(phoneNumber.e164);
    } on Failure {
      rethrow;
    } catch (_) {
      // Transport-level errors never reach the UI as-is.
      throw const Failure.unexpected();
    }
  }

  @override
  Future<void> verifyOtp({
    required String verificationId,
    required OtpCode code,
    String? role,
  }) async {
    try {
      await _remoteDataSource.confirmOtp(
        verificationId,
        code.digits,
        role: role,
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remoteDataSource.signOut();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }
}
