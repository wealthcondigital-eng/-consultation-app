import 'dart:math';

import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_thread.dart';
import '../../domain/entities/voice_note.dart';

/// Reads and writes the patient–doctor conversation on the backend.
abstract interface class ChatRemoteDataSource {
  Future<ChatThread> openThread({
    required Doctor doctor,
    required ConsultationMode mode,
    String? anonymousDisplayName,
  });

  Future<ChatMessage> sendText({
    required String threadId,
    required String body,
  });

  Future<ChatMessage> sendVoiceNote({
    required String threadId,
    required VoiceNote note,
  });
}

/// Stand-in until the messaging service exists. Swap for a websocket or HTTP
/// implementation — nothing above this layer changes.
///
/// Threads are held in memory for the run, so a message sent here survives
/// leaving the screen and coming back, the way the real thread would.
class FakeChatRemoteDataSource implements ChatRemoteDataSource {
  FakeChatRemoteDataSource();

  /// Keyed by thread id, which is derived from the doctor.
  final Map<String, ChatThread> _threads = {};

  final Random _random = Random();

  int _sequence = 0;

  @override
  Future<ChatThread> openThread({
    required Doctor doctor,
    required ConsultationMode mode,
    String? anonymousDisplayName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final threadId = 'thread-${doctor.id}';
    final existing = _threads[threadId];
    if (existing != null) {
      return existing.copyWith(isDoctorOnline: doctor.isAvailableNow);
    }

    final thread = ChatThread(
      id: threadId,
      doctor: doctor,
      patientDisplayName: anonymousDisplayName ?? 'You',
      mode: mode,
      isAnonymous: anonymousDisplayName != null,
      isDoctorOnline: doctor.isAvailableNow,
      messages: _seedMessages(doctor),
    );

    _threads[threadId] = thread;
    return thread;
  }

  @override
  Future<ChatMessage> sendText({
    required String threadId,
    required String body,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    return _append(
      threadId,
      ChatMessage.text(
        id: _nextId(),
        author: ChatAuthor.patient,
        sentAt: DateTime.now(),
        body: body,
      ),
    );
  }

  @override
  Future<ChatMessage> sendVoiceNote({
    required String threadId,
    required VoiceNote note,
  }) async {
    // Longer than a text send: the clip has to go up first.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    return _append(
      threadId,
      ChatMessage.voice(
        id: _nextId(),
        author: ChatAuthor.patient,
        sentAt: DateTime.now(),
        // The service hands back where it stored the audio.
        note: VoiceNote(
          id: note.id,
          duration: note.duration,
          waveform: note.waveform,
          url: 'https://example.invalid/voice/${note.id}.m4a',
        ),
      ),
    );
  }

  /// Files [message] into its thread and returns it.
  ChatMessage _append(String threadId, ChatMessage message) {
    final thread = _threads[threadId];
    if (thread != null) {
      _threads[threadId] = thread.copyWith(
        messages: [...thread.messages, message],
      );
    }

    return message;
  }

  String _nextId() => 'msg-${++_sequence}';

  /// The history the patient already has with this doctor: the recording kept
  /// from their last consultation, and the notes either side of it.
  List<ChatMessage> _seedMessages(Doctor doctor) {
    final now = DateTime.now();
    final lastConsultation = now.subtract(const Duration(days: 3));

    return [
      ChatMessage.text(
        id: 'seed-1',
        author: ChatAuthor.doctor,
        sentAt: lastConsultation.subtract(const Duration(minutes: 20)),
        body:
            'Thanks for joining the call. I have shared a short summary '
            'below along with the recording.',
      ),
      ChatMessage.consultationRecording(
        id: 'seed-2',
        sentAt: lastConsultation,
        summary:
            'Recording of your last consultation with '
            '${doctor.name.split(' ').last}',
        note: VoiceNote(
          id: 'recording-${doctor.id}',
          duration: const Duration(minutes: 4, seconds: 12),
          waveform: _waveform(48, seed: doctor.id.hashCode),
          url: 'https://example.invalid/recordings/${doctor.id}.m4a',
          transcript:
              'Discussed sleep, stress triggers and a four-week '
              'breathing routine.',
        ),
      ),
      ChatMessage.text(
        id: 'seed-3',
        author: ChatAuthor.doctor,
        sentAt: lastConsultation.add(const Duration(minutes: 2)),
        body:
            'Play it back any time. Send me a voice note if anything '
            'changes before we speak again.',
      ),
    ];
  }

  /// A plausible-looking set of bars. The real clip's amplitudes come from the
  /// recorder; this only has to look like audio.
  List<double> _waveform(int bars, {int? seed}) {
    final random = seed == null ? _random : Random(seed);

    return List<double>.generate(
      bars,
      // Kept off the floor so no bar disappears entirely.
      (index) => 0.25 + random.nextDouble() * 0.75,
    );
  }
}
