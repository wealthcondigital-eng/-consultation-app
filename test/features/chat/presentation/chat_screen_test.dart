import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/features/anonymous/domain/entities/anonymous_session.dart';
import 'package:consultation_app/features/anonymous/domain/entities/code_name.dart';
import 'package:consultation_app/features/anonymous/domain/entities/consult_language.dart';
import 'package:consultation_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:consultation_app/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:consultation_app/features/chat/presentation/widgets/consultation_recording_card.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:flutter/material.dart';
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

const _session = AnonymousSession(
  codeName: CodeName('Patient Hawk'),
  mode: ConsultationMode.audio,
  language: ConsultLanguage.english,
);

/// Screens the thread must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _openChat(
  WidgetTester tester,
  Size size, {
  AnonymousSession? session = _session,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TeleconsultApp(
      initialRoute: AppRoutes.chat,
      initialRouteArguments: ChatArgs(
        doctor: _doctor,
        mode: ConsultationMode.audio,
        anonymousSession: session,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _composerField() => find.widgetWithText(TextField, 'Write a message');

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('ChatScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openChat(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Dr. Amit Verma'), findsOneWidget);
        expect(_composerField(), findsOneWidget);
      });
    }

    testWidgets('the last consultation recording is waiting in the thread', (
      tester,
    ) async {
      await _openChat(tester, const Size(402, 874));

      expect(find.byType(ConsultationRecordingCard), findsOneWidget);
      expect(
        find.textContaining('Recording of your last consultation'),
        findsOneWidget,
      );
      // Dated, timed, and playable.
      expect(find.textContaining('4:12'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('playing the recording pauses on a second tap', (tester) async {
      await _openChat(tester, const Size(402, 874));

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      // The clock has moved off the clip length.
      expect(find.textContaining('4:12'), findsNothing);

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('an anonymous thread says which alias the doctor sees', (
      tester,
    ) async {
      await _openChat(tester, const Size(402, 874));

      expect(find.textContaining('You appear as Patient Hawk'), findsOneWidget);
      expect(find.textContaining('as Patient Hawk'), findsWidgets);
    });

    testWidgets('sending a message adds it to the thread', (tester) async {
      await _openChat(tester, const Size(402, 874));

      final bubblesBefore = tester.widgetList(find.byType(ChatBubble)).length;

      await tester.enterText(_composerField(), 'Sleeping better this week');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      // Long enough for the send to come back and settle.
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Sleeping better this week'), findsOneWidget);
      expect(
        tester.widgetList(find.byType(ChatBubble)).length,
        bubblesBefore + 1,
      );
      // The composer is cleared and back to offering the mic.
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    testWidgets('holding the mic records a note and releasing sends it', (
      tester,
    ) async {
      await _openChat(tester, const Size(402, 874));

      final bubblesBefore = tester.widgetList(find.byType(ChatBubble)).length;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.mic_none_rounded)),
      );
      // Past the long-press threshold, then long enough to be speech.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.fiber_manual_record), findsOneWidget);

      await gesture.up();
      await tester.pump();
      // The clip is uploaded before the bubble settles.
      await tester.pump(const Duration(seconds: 2));

      expect(
        tester.widgetList(find.byType(ChatBubble)).length,
        bubblesBefore + 1,
      );
      expect(find.byIcon(Icons.fiber_manual_record), findsNothing);
    });

    testWidgets('a recording too short to be speech is not sent', (
      tester,
    ) async {
      await _openChat(tester, const Size(402, 874));

      final bubblesBefore = tester.widgetList(find.byType(ChatBubble)).length;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.mic_none_rounded)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.widgetList(find.byType(ChatBubble)).length, bubblesBefore);
      expect(
        find.text('Hold the mic a little longer to record a note.'),
        findsOneWidget,
      );
    });

    testWidgets('a named patient gets no alias strip', (tester) async {
      await _openChat(tester, const Size(402, 874), session: null);

      expect(find.textContaining('You appear as'), findsNothing);
      expect(find.byType(ConsultationRecordingCard), findsOneWidget);
    });
  });
}
