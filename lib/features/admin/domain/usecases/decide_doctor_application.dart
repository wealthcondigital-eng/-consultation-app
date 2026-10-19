import '../../../../core/error/failure.dart';
import '../repositories/admin_repository.dart';

/// Approves or rejects one registration.
class DecideDoctorApplication {
  const DecideDoctorApplication(this._repository);

  final AdminRepository _repository;

  static const int minReasonLength = 10;

  Future<void> approve(String doctorId) => _repository.approve(doctorId);

  Future<void> reject(String doctorId, String reason) {
    // A doctor has to know what to fix; "no" on its own sends them back to the
    // same form with the same mistake.
    if (reason.trim().length < minReasonLength) {
      throw const Failure(
        'Give a reason the doctor can act on, of at least 10 characters.',
      );
    }
    return _repository.reject(doctorId, reason.trim());
  }
}
