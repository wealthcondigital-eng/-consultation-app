import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/core/branding/app_brand.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the landing page must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro — design frame (402x874)': Size(402, 874),
  'Galaxy S24 Ultra (480x1010)': Size(480, 1010),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const TeleconsultApp());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('LandingScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _pumpAt(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text(AppBrand.name), findsOneWidget);
        expect(find.text('Care. Anytime. Anywhere.'), findsOneWidget);
        expect(find.text('Continue as Patient'), findsOneWidget);
        expect(find.text('Continue as Doctor'), findsOneWidget);
        expect(
          find.text('Trusted by doctors. Loved by patients.'),
          findsOneWidget,
        );
      });
    }

    testWidgets('keeps buttons within the tappable minimum', (tester) async {
      await _pumpAt(tester, const Size(320, 568));

      final button = tester.getSize(
        find.widgetWithText(FilledButton, 'Continue as Patient'),
      );
      expect(button.height, greaterThanOrEqualTo(44));
    });

    testWidgets('caps the content column on a tablet', (tester) async {
      await _pumpAt(tester, const Size(1366, 1024));

      final button = tester.getSize(
        find.widgetWithText(FilledButton, 'Continue as Patient'),
      );
      // Would be ~1300 wide if the phone layout were stretched edge to edge.
      expect(button.width, lessThan(500));
    });

    testWidgets('patient opens the phone login flow', (tester) async {
      await _pumpAt(tester, const Size(402, 874));

      await tester.tap(find.text('Continue as Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text("Let's Get Started"), findsOneWidget);

      // The chosen journey is named on the login screen. It is the last point
      // at which going back costs nothing: a number registered under the other
      // role is not refused until after the code has been verified.
      expect(find.text('Continuing as Patient'), findsOneWidget);
    });

    testWidgets('doctor opens the same phone login flow', (tester) async {
      await _pumpAt(tester, const Size(402, 874));

      await tester.tap(find.text('Continue as Doctor'));
      await tester.pumpAndSettle();

      // The role is what differs afterwards, not the login itself — and the
      // login screen says which one it is carrying.
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text("Let's Get Started"), findsOneWidget);
      expect(find.text('Continuing as Doctor'), findsOneWidget);
    });
  });
}
