import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/branding/app_brand.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the splash must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro — design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

/// Launches the app the way `main` does: on the splash.
///
/// Never `pumpAndSettle` straight after — the splash holds the brand on a
/// timer, and a launch slow enough to show the progress hint spins an
/// indicator that never settles. Every wait here is bounded.
Future<void> _launch(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(const TeleconsultApp(initialRoute: AppRoutes.splash));
  await tester.pump();
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('SplashScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _launch(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text(AppBrand.name), findsOneWidget);
        expect(find.text('Care. Anytime. Anywhere.'), findsOneWidget);
      });
    }

    testWidgets('holds the brand before handing over to the role choice', (
      tester,
    ) async {
      await _launch(tester, const Size(402, 874));

      // The destination is decided in microseconds against the fake backend.
      // Handing over that fast would flash the brand for a single frame, so the
      // splash is still up well after the answer is in.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(AppBrand.name), findsOneWidget);
      expect(find.text('Continue as Patient'), findsNothing);

      // And gone once the hold is over.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.text('Continue as Patient'), findsOneWidget);
    });

    testWidgets('shows no progress hint on a launch that is not slow', (
      tester,
    ) async {
      await _launch(tester, const Size(402, 874));
      await tester.pump(const Duration(milliseconds: 400));

      // A spinner for a fifth of a second is noise. It is only earned by a
      // launch that outruns the hold.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('leaves no timer running when the launch is abandoned', (
      tester,
    ) async {
      await _launch(tester, const Size(402, 874));

      // Mid-hold: the screen goes away with the brand still up, which is what
      // happens when the app-wide session gate redirects out from under it.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox.shrink());

      // The framework asserts on a pending timer at the end of the test, so
      // reaching here with a clean exception log is the assertion.
      expect(tester.takeException(), isNull);
    });
  });
}
