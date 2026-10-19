import '../entities/consult_option.dart';
import '../repositories/consultation_repository.dart';

/// Loads the ways a patient can start a consultation.
class GetConsultOptions {
  const GetConsultOptions(this._repository);

  final ConsultationRepository _repository;

  Future<List<ConsultOption>> call() => _repository.fetchConsultOptions();
}
