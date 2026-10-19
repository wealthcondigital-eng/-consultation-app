import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../entities/payment_summary.dart';
import '../repositories/payment_repository.dart';

/// Builds the charge shown on the payment screen.
class GetPaymentSummary {
  const GetPaymentSummary(this._repository);

  final PaymentRepository _repository;

  Future<PaymentSummary> call({
    required Doctor doctor,
    ConsultationMode mode = ConsultationMode.video,
  }) {
    return _repository.fetchSummary(doctor: doctor, mode: mode);
  }
}
