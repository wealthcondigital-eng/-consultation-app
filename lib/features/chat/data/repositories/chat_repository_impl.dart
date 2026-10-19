import '../../../../core/error/failure.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_thread.dart';
import '../../domain/entities/voice_note.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this._remoteDataSource);

  final ChatRemoteDataSource _remoteDataSource;

  @override
  Future<ChatThread> openThread({
    required Doctor doctor,
    required ConsultationMode mode,
    String? anonymousDisplayName,
  }) async {
    try {
      return await _remoteDataSource.openThread(
        doctor: doctor,
        mode: mode,
        anonymousDisplayName: anonymousDisplayName,
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }

  @override
  Future<ChatMessage> sendText({
    required String threadId,
    required String body,
  }) async {
    try {
      return await _remoteDataSource.sendText(threadId: threadId, body: body);
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }

  @override
  Future<ChatMessage> sendVoiceNote({
    required String threadId,
    required VoiceNote note,
  }) async {
    try {
      return await _remoteDataSource.sendVoiceNote(
        threadId: threadId,
        note: note,
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }
}
