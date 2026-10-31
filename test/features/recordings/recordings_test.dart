import 'package:consultation_app/app/router/app_router.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/responsive/app_sizing.dart';
import 'package:consultation_app/features/recordings/data/recordings_remote_data_source.dart';
import 'package:consultation_app/features/recordings/domain/entities/call_recording.dart';
import 'package:consultation_app/features/recordings/presentation/controllers/recordings_controller.dart';
import 'package:consultation_app/features/recordings/presentation/screens/recording_player_screen.dart';
import 'package:consultation_app/features/recordings/presentation/screens/recordings_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CallRecording _recording(
  String id, {
  String doctor = 'doc-1',
  String doctorName = 'Dr. Amit Verma',
  bool video = true,
  int day = 1,
}) => CallRecording(
  id: id,
  consultationId: 'c-$id',
  isVideo: video,
  duration: const Duration(minutes: 12, seconds: 4),
  sizeBytes: 18 * 1024 * 1024,
  mimeType: video ? 'video/mp4' : 'audio/mp4',
  recordedAt: DateTime(2026, 10, day, 16, 30),
  streamUrl: '/recordings/$id/stream',
  doctorUserId: doctor,
  doctorName: doctorName,
  patientUserId: 'patient-1',
  patientName: 'Monalisa',
);

class _Source implements RecordingsRemoteDataSource {
  _Source(this.rows);

  final List<CallRecording> rows;

  @override
  Future<List<CallRecording>> fetch({String? withUserId}) async => [
    for (final row in rows)
      if (withUserId == null ||
          row.doctorUserId == withUserId ||
          row.patientUserId == withUserId)
        row,
  ];
}

void main() {
  test(
    'groups recordings into one thread per counterpart, newest first',
    () async {
      final controller = RecordingsController(
        _Source([
          _recording('a', day: 1),
          _recording('b', doctor: 'doc-2', doctorName: 'Dr. Rao', day: 3),
          _recording('c', day: 5, video: false),
        ]),
        viewerUserId: 'patient-1',
      );

      await controller.load();
      final threads = controller.threads;

      expect(threads, hasLength(2));
      expect(threads.first.counterpart.name, 'Dr. Amit Verma');
      expect(threads.first.recordings.map((r) => r.id), ['c', 'a']);
      expect(threads.last.counterpart.name, 'Dr. Rao');
    },
  );

  test('reads the transcript, and treats a failed one as unavailable', () {
    expect(TranscriptStatus.from('pending'), TranscriptStatus.preparing);
    expect(TranscriptStatus.from('processing'), TranscriptStatus.preparing);
    expect(TranscriptStatus.from('ready'), TranscriptStatus.ready);
    expect(TranscriptStatus.from('failed'), TranscriptStatus.unavailable);
    expect(TranscriptStatus.from(null), TranscriptStatus.unavailable);

    const empty = RecordingTranscript(status: TranscriptStatus.ready);
    expect(empty.hasText, isFalse);
  });

  test('a doctor sees the patient as the counterpart', () {
    final recording = _recording('a');
    expect(recording.counterpartOf('doc-1').name, 'Monalisa');
    expect(recording.counterpartOf('patient-1').name, 'Dr. Amit Verma');
    expect(recording.durationLabel, '12:04');
    expect(recording.sizeLabel, '18.0 MB');
  });

  group('recordings chat', () {
    setUp(() {
      sl.reset();
      configureDependencies();
      // Registering again replaces the fake, which has no recordings.
      sl.registerLazySingleton<RecordingsRemoteDataSource>(
        () => _Source([_recording('a', day: 1), _recording('b', video: false)]),
      );
    });

    testWidgets('lists the recordings, has no way to type, opens the player', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          builder: (context, child) => AppSizingScope(child: child!),
          home: const RecordingsChatScreen(
            args: RecordingsChatArgs(
              counterpart: RecordingParty(
                userId: 'doc-1',
                name: 'Dr. Amit Verma',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dr. Amit Verma'), findsOneWidget);
      // A video tile for the video call, a voice message for the audio one.
      expect(find.text('Video call recording'), findsOneWidget);
      expect(find.text('Audio call recording'), findsOneWidget);
      expect(find.byKey(const ValueKey('recording-video-a')), findsOneWidget);
      expect(find.byTooltip('Play'), findsOneWidget);
      expect(
        find.text(
          'Messaging is not available. Only call recordings are shared here.',
        ),
        findsOneWidget,
      );
      // A chat with nothing to type into.
      expect(find.byType(TextField), findsNothing);
      // Each recording carries its transcript area; neither has one yet.
      expect(find.text('No transcript available'), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('recording-video-a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(RecordingPlayerScreen), findsOneWidget);
    });
  });
}
