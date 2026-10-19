import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../entities/chat_thread.dart';
import '../repositories/chat_repository.dart';

/// Loads the conversation with a doctor, including anything kept from earlier
/// consultations with them.
class OpenChatThread {
  const OpenChatThread(this._repository);

  final ChatRepository _repository;

  Future<ChatThread> call({
    required Doctor doctor,
    required ConsultationMode mode,
    String? anonymousDisplayName,
  }) {
    return _repository.openThread(
      doctor: doctor,
      mode: mode,
      anonymousDisplayName: anonymousDisplayName,
    );
  }
}
