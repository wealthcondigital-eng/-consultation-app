import '../entities/chat_message.dart';
import '../entities/voice_note.dart';
import '../repositories/chat_repository.dart';

/// Posts the patient's side of the conversation — text or audio.
class SendChatMessage {
  const SendChatMessage(this._repository);

  final ChatRepository _repository;

  /// Sends [body]. Empty or whitespace-only text is rejected here rather than
  /// in the widget, so every caller obeys the same rule.
  Future<ChatMessage> text({required String threadId, required String body}) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('A message cannot be empty.');
    }

    return _repository.sendText(threadId: threadId, body: trimmed);
  }

  Future<ChatMessage> voiceNote({
    required String threadId,
    required VoiceNote note,
  }) {
    if (note.duration <= Duration.zero) {
      throw ArgumentError('A voice note needs some audio in it.');
    }

    return _repository.sendVoiceNote(threadId: threadId, note: note);
  }
}
