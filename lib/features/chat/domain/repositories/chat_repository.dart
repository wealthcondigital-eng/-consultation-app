import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../entities/chat_message.dart';
import '../entities/chat_thread.dart';
import '../entities/voice_note.dart';

/// Contract for the patient–doctor conversation.
abstract interface class ChatRepository {
  /// The thread with [doctor], created if this is their first contact. Passing
  /// [anonymousDisplayName] keeps the patient's real identity out of it.
  Future<ChatThread> openThread({
    required Doctor doctor,
    required ConsultationMode mode,
    String? anonymousDisplayName,
  });

  /// Sends a line of text and returns it as the backend stored it.
  Future<ChatMessage> sendText({
    required String threadId,
    required String body,
  });

  /// Uploads a recording the patient just made.
  Future<ChatMessage> sendVoiceNote({
    required String threadId,
    required VoiceNote note,
  });
}
