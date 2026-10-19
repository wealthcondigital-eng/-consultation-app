import '../entities/consult_option.dart';

/// Contract for the consultation options a patient can choose from.
abstract interface class ConsultationRepository {
  /// Loads the available options, including the current estimated wait.
  Future<List<ConsultOption>> fetchConsultOptions();
}
