import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/features/consultation/data/datasources/matchmaking_remote_data_source.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/consultation/domain/entities/matching_step.dart';
import 'package:consultation_app/features/consultation/presentation/screens/doctor_matching_screen.dart';
import 'package:consultation_app/features/consultation/presentation/widgets/matching_progress_ring.dart';
import 'package:consultation_app/features/consultation/presentation/widgets/matching_steps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the matching page must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

/// One stage of the stubbed backend, plus a frame to render it.
Future<void> _advanceOneStep(WidgetTester tester) async {
  await tester.pump(FakeMatchmakingRemoteDataSource.stepDuration);
  await tester.pump();
}

Future<void> _openMatching(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // The ring animates and the countdown ticks forever, so the tree is torn
  // down explicitly rather than left for the binding to complain about.
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(
    const TeleconsultApp(
      initialRoute: AppRoutes.doctorMatching,
      initialRouteArguments: DoctorMatchingArgs(mode: ConsultationMode.video),
    ),
  );
  // Enough for the route transition and the estimate to arrive.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('DoctorMatchingScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openMatching(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.byType(MatchingProgressRing), findsOneWidget);
        expect(find.text('Finding you the best doctor...'), findsOneWidget);
        expect(
          find.text('Please wait while we connect you to an available doctor'),
          findsOneWidget,
        );
        expect(find.byType(MatchingSteps), findsOneWidget);
        for (final step in MatchingStep.values) {
          expect(find.text(step.label), findsOneWidget);
        }
        expect(find.text('Cancel'), findsOneWidget);
      });
    }

    testWidgets('counts the estimate down', (tester) async {
      await _openMatching(tester, const Size(402, 874));

      expect(find.text('Estimated time 00:45'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Estimated time 00:42'), findsOneWidget);
    });

    testWidgets('ticks the steps off in order', (tester) async {
      await _openMatching(tester, const Size(402, 874));

      // Nothing is done at the start.
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      await _advanceOneStep(tester);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await _advanceOneStep(tester);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });

    testWidgets('reports the doctor once matching completes', (tester) async {
      await _openMatching(tester, const Size(402, 874));

      for (var index = 0; index < MatchingStep.values.length; index++) {
        await _advanceOneStep(tester);
      }

      expect(find.text('Doctor found'), findsOneWidget);
      expect(find.text('Dr. Amit Verma is joining now'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
      // The waiting language is gone.
      expect(find.text('Finding you the best doctor...'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('Cancel returns to home', (tester) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      // Pushed on top of home so there is somewhere to return to.
      await tester.pumpWidget(
        const TeleconsultApp(initialRoute: AppRoutes.home),
      );
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(
        AppRoutes.doctorMatching,
        arguments: const DoctorMatchingArgs(mode: ConsultationMode.video),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      // Two jumps: one to run the reverse transition, one to let the popped
      // route be disposed.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MatchingProgressRing), findsNothing);
      expect(find.text('How can we help you today?'), findsOneWidget);
    });
  });
}
