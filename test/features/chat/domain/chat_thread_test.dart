import 'package:consultation_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:consultation_app/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:consultation_app/features/chat/domain/entities/chat_message.dart';
import 'package:consultation_app/features/chat/domain/entities/voice_note.dart';
import 'package:consultation_app/features/chat/domain/usecases/open_chat_thread.dart';
import 'package:consultation_app/features/chat/domain/usecases/send_chat_message.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:flutter_test/flutter_test.dart';

const _doctor = Doctor(
  id: 'amit-verma',
  name: 'Dr. Amit Verma',
  speciality: 'Senior Cardiologist',
  yearsOfExperience: 15,
  rating: 4.9,
  consultationFee: 800,
  audioConsultationFee: 600,
  isVerified: true,
  isAvailableNow: true,
);

void main() {
  group('VoiceNote', () {
    const note = VoiceNote(
      id: 'note-1',
      duration: Duration(minutes: 4, seconds: 12),
      waveform: [0.5, 0.5],
    );

    test('reads its length as minutes and seconds', () {
      expect(note.durationLabel, '4:12');
      expect(VoiceNote.formatPosition(const Duration(seconds: 7)), '0:07');
    });

    test('reports progress as a bounded fraction', () {
      expect(note.progressAt(Duration.zero), 0);
      expect(note.progressAt(const Duration(minutes: 2, seconds: 6)), 0.5);
      expect(note.progressAt(const Duration(hours: 1)), 1);
    });
  });

  group('ChatMessage', () {
    test('formats the clock in twelve-hour time', () {
      final morning = ChatMessage.text(
        id: 'm',
        author: ChatAuthor.doctor,
        sentAt: DateTime(2026, 8, 12, 9, 41),
        body: 'Hello',
      );
      final midnight = ChatMessage.text(
        id: 'n',
        author: ChatAuthor.doctor,
        sentAt: DateTime(2026, 8, 12, 0, 5),
        body: 'Hello',
      );

      expect(morning.timeLabel, '9:41 am');
      expect(morning.dateLabel, '12 Aug');
      expect(midnight.timeLabel, '12:05 am');
    });
  });

  group('Chat repository', () {
    late OpenChatThread openThread;
    late SendChatMessage sendMessage;

    setUp(() {
      final repository = ChatRepositoryImpl(FakeChatRemoteDataSource());
      openThread = OpenChatThread(repository);
      sendMessage = SendChatMessage(repository);
    });

    test(
      'a new thread carries the recording from the last consultation',
      () async {
        final thread = await openThread(
          doctor: _doctor,
          mode: ConsultationMode.audio,
        );

        final recording = thread.consultationRecording;
        expect(recording, isNotNull);
        expect(recording!.isVoiceNote, isTrue);
        expect(recording.voiceNote!.durationLabel, '4:12');
        expect(recording.text, contains('last consultation'));
      },
    );

    test('an anonymous thread shows the alias and not a real name', () async {
      final thread = await openThread(
        doctor: _doctor,
        mode: ConsultationMode.audio,
        anonymousDisplayName: 'Patient Hawk',
      );

      expect(thread.isAnonymous, isTrue);
      expect(thread.patientDisplayName, 'Patient Hawk');
    });

    test('reopening a thread keeps what was already sent', () async {
      final thread = await openThread(
        doctor: _doctor,
        mode: ConsultationMode.audio,
      );
      final before = thread.messages.length;

      await sendMessage.text(threadId: thread.id, body: '  Feeling better  ');
      final reopened = await openThread(
        doctor: _doctor,
        mode: ConsultationMode.audio,
      );

      expect(reopened.messages.length, before + 1);
      expect(reopened.messages.last.text, 'Feeling better');
      expect(reopened.messages.last.isFromPatient, isTrue);
    });

    test('a voice note comes back with somewhere to play it from', () async {
      final thread = await openThread(
        doctor: _doctor,
        mode: ConsultationMode.audio,
      );

      final sent = await sendMessage.voiceNote(
        threadId: thread.id,
        note: const VoiceNote(
          id: 'local-1',
          duration: Duration(seconds: 9),
          waveform: [0.4, 0.9, 0.3],
        ),
      );

      expect(sent.isVoiceNote, isTrue);
      expect(sent.voiceNote!.url, isNotNull);
      expect(sent.voiceNote!.duration, const Duration(seconds: 9));
    });

    test('refuses an empty message and a silent recording', () {
      expect(
        () => sendMessage.text(threadId: 'thread-amit-verma', body: '   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => sendMessage.voiceNote(
          threadId: 'thread-amit-verma',
          note: const VoiceNote(
            id: 'empty',
            duration: Duration.zero,
            waveform: [],
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
