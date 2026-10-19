import '../../../../core/error/failure.dart';
import '../entities/payment_method.dart';
import '../entities/payment_summary.dart';
import '../entities/upi_id.dart';
import '../repositories/payment_repository.dart';

/// Charges the patient for a consultation.
class PayForConsultation {
  const PayForConsultation(this._repository);

  final PaymentRepository _repository;

  /// Returns the transaction reference.
  Future<String> call({
    required PaymentSummary summary,
    required PaymentMethod method,
    UpiId? upiId,
    String? consultationId,
  }) {
    // A money-moving call must not depend on the screen having validated.
    if (method.needsUpiId && (upiId == null || !upiId.isWellFormed)) {
      throw const Failure('Enter a valid UPI ID before paying.');
    }

    return _repository.pay(
      summary: summary,
      method: method,
      upiId: upiId,
      consultationId: consultationId,
    );
  }
}
