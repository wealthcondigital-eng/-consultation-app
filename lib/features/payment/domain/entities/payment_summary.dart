import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import 'fee_breakdown.dart';

/// Everything the payment screen shows above the method picker.
class PaymentSummary {
  const PaymentSummary({
    required this.doctor,
    required this.mode,
    required this.fees,
    this.isTestMode = false,
  });

  /// True when the server is on a Razorpay **test** key: no real money moves,
  /// and the payment screen says so.
  final bool isTestMode;

  final Doctor doctor;
  final ConsultationMode mode;
  final FeeBreakdown fees;
}
