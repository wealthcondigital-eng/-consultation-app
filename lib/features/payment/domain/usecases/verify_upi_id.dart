import '../../../../core/error/failure.dart';
import '../entities/upi_id.dart';
import '../repositories/payment_repository.dart';

/// Confirms a UPI address before the patient is charged.
class VerifyUpiId {
  const VerifyUpiId(this._repository);

  final PaymentRepository _repository;

  /// Returns the account holder's name.
  Future<String> call(UpiId upiId) {
    // Caught here so an obviously malformed address never costs a round trip.
    if (!upiId.isWellFormed) {
      throw const Failure('Enter a UPI ID like name@bank.');
    }
    return _repository.verifyUpiId(upiId);
  }
}
