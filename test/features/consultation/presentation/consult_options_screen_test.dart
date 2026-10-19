import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/features/consultation/presentation/widgets/consult_option_card.dart';
import 'package:consultation_app/features/consultation/presentation/widgets/matching_progress_ring.dart';
import 'package:consultation_app/features/onboarding/domain/entities/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the consult options page must lay out cleanly on.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _openOptions(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const TeleconsultApp(initialRoute: AppRoutes.consultOptions),
  );
  await tester.pumpAndSettle();
}

/// Walks in from home the way a patient would.
Future<void> _openViaHome(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const TeleconsultApp(
      initialRoute: AppRoutes.home,
      initialRouteArguments: UserRole.patient,
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Consult Now'));
  await tester.pumpAndSettle();
}

/// Frames enough for the discovery search to finish and hand over.
///
/// It is a real query plus a deliberate hold so the progress ring is legible,
/// rather than the stub's fixed march through three timed steps.
Future<void> _settleSearch(WidgetTester tester) async {
  for (var index = 0; index < 4; index++) {
    await tester.pump(const Duration(milliseconds: 600));
  }
  await _settleRoute(tester);
}

/// Frames enough for a route transition to run and the next screen's first
/// load to arrive. Not pumpAndSettle: the matching ring never stops animating.
Future<void> _settleRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('ConsultOptionsScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openOptions(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.byType(ConsultOptionCard), findsNWidgets(2));
        expect(find.text('Instant Consultation'), findsOneWidget);
        expect(find.text('Estimated Wait: ~4 mins'), findsOneWidget);
        expect(find.text('Connect Now'), findsOneWidget);
        expect(find.text('Scheduled Consultation'), findsOneWidget);
        expect(
          find.text('Book slots for later today or tomorrow'),
          findsOneWidget,
        );
        expect(find.text('Book Appointment'), findsOneWidget);
      });
    }

    testWidgets('shows a spinner until the options arrive', (tester) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const TeleconsultApp(initialRoute: AppRoutes.consultOptions),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ConsultOptionCard), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(ConsultOptionCard), findsNWidgets(2));
    });

    testWidgets('the home Consult Now card opens this screen', (tester) async {
      await _openViaHome(tester, const Size(402, 874));

      expect(find.byType(ConsultOptionCard), findsNWidgets(2));
      // The screen title reuses the card's label.
      expect(find.text('Consult Now'), findsWidgets);
    });

    testWidgets('back returns to home', (tester) async {
      await _openViaHome(tester, const Size(402, 874));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(ConsultOptionCard), findsNothing);
      expect(find.text('How can we help you today?'), findsOneWidget);
    });

    testWidgets('the immediate option searches, then lists who is available', (
      tester,
    ) async {
      // The matching ring spins forever, so the tree is torn down explicitly.
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await _openOptions(tester, const Size(402, 874));

      await tester.tap(find.widgetWithText(FilledButton, 'Connect Now'));
      // Bounded frames, not pumpAndSettle: the search now runs to completion
      // on its own, and settling would step straight past the state under test.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No call type is asked for here any more. It is a question about a
      // particular doctor — they may take only one of the two, and they price
      // them separately — so it comes after one has been chosen.
      expect(find.text('How would you like to consult?'), findsNothing);

      // Searching comes first, listing only after it finishes. The wording is
      // the session's, so the screen and the dashboard card that reports the
      // same search in the background say the same thing.
      expect(find.text('Finding a doctor'), findsOneWidget);
      expect(find.byType(MatchingProgressRing), findsOneWidget);

      // Backing out is not cancelling any more — the search runs on and the
      // dashboard reports it — so the way out is offered as such.
      expect(find.text('Search in the background'), findsOneWidget);

      await _settleSearch(tester);

      expect(find.byType(MatchingProgressRing), findsNothing);
      expect(find.text('Available Doctors'), findsOneWidget);
    });

    testWidgets('a search backed out of keeps running on the dashboard', (
      tester,
    ) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await _openViaHome(tester, const Size(402, 874));

      await tester.tap(find.widgetWithText(FilledButton, 'Connect Now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The gap this closes: backing out of the search threw it away with
      // nothing said, and the patient had to start again from Consult Now.
      await tester.tap(find.text('Search in the background'));
      // Bounded frames, not pumpAndSettle: settling would run the search to
      // completion and step straight past the state under test, which is a
      // search still going while the patient is back on their dashboard.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MatchingProgressRing), findsNothing);
      expect(find.text('Finding a doctor'), findsOneWidget);

      // And it finishes where it is, on the dashboard.
      await _settleSearch(tester);

      expect(find.textContaining('doctor'), findsWidgets);
      expect(find.text('See doctors'), findsOneWidget);
    });

    testWidgets('the scheduled option matches, then lists every doctor', (
      tester,
    ) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await _openOptions(tester, const Size(402, 874));

      // The second card sits below the fold on a phone-sized viewport.
      final button = find.widgetWithText(OutlinedButton, 'Book Appointment');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MatchingProgressRing), findsOneWidget);

      await _settleSearch(tester);

      expect(find.byType(MatchingProgressRing), findsNothing);
      // Not restricted to who is free this minute, unlike the instant flow.
      expect(find.text('Verified Doctors'), findsOneWidget);
    });
  });
}
