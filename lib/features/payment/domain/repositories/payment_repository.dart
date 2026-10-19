import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../entities/payment_method.dart';
import '../entities/payment_summary.dart';
import '../entities/upi_id.dart';

/// Contract for paying for a consultation.
abstract interface class PaymentRepository {
  /// True when the gateway asks for the payment method itself, so the screen
  /// must not offer a picker of its own.
  bool get gatewayCollectsMethod;

  /// Builds the charge for a consultation with [doctor].
  Future<PaymentSummary> fetchSummary({
    required Doctor doctor,
    required ConsultationMode mode,
  });

  /// Confirms a UPI address exists, returning the account holder's name.
  Future<String> verifyUpiId(UpiId upiId);

  /// Takes the payment and returns the transaction reference.
  ///
  /// [consultationId] is the booking this settles, where one has already been
  /// filed. Carried so the server can mark it paid: a held slot and a paid
  /// appointment are the same row without it, and the doctor cannot tell which
  /// of the two people in their diary actually went through with it.
  Future<String> pay({
    required PaymentSummary summary,
    required PaymentMethod method,
    UpiId? upiId,
    String? consultationId,
  });
}
