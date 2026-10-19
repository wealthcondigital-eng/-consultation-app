import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/core/branding/app_brand.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the login page must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro — design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

/// Boots the app and walks to the login screen the way a user would.
Future<void> _openLogin(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Tearing the tree down disposes any controller the test navigated to — the
  // OTP screen's resend countdown would otherwise outlive the test.
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(const TeleconsultApp());
  await tester.pumpAndSettle();

  await tester.tap(find.text('Continue as Patient'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('PhoneLoginScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openLogin(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Sign in'), findsOneWidget);
        expect(find.text("Let's Get Started"), findsOneWidget);
        expect(find.textContaining('Enter your mobile number'), findsOneWidget);
        expect(find.text('Phone Number'), findsOneWidget);
        expect(find.text('+91'), findsOneWidget);
      });
    }

    testWidgets('offers no sign-in route other than the phone number', (
      tester,
    ) async {
      await _openLogin(tester, const Size(402, 874));

      // Google sign-in is gone; the phone OTP is the only way in,
      // so neither the button nor the divider that introduced it should be
      // left behind.
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('OR'), findsNothing);
    });

    testWidgets('Continue stays disabled until the number is complete', (
      tester,
    ) async {
      await _openLogin(tester, const Size(402, 874));

      FilledButton continueButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );

      expect(continueButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), '98765');
      await tester.pump();
      expect(continueButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pump();
      expect(continueButton().onPressed, isNotNull);
    });

    testWidgets('formats the number as it is typed', (tester) async {
      await _openLogin(tester, const Size(402, 874));

      // Deliberately not the sample number, which is on screen as the hint.
      await tester.enterText(find.byType(TextField), '9012345678');
      await tester.pump();

      expect(find.text('90123 45678'), findsOneWidget);
    });

    testWidgets('requesting an OTP shows progress then opens verification', (
      tester,
    ) async {
      await _openLogin(tester, const Size(402, 874));

      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Bounded pumps rather than pumpAndSettle: the OTP screen starts a
      // countdown that reschedules every second.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Enter OTP'), findsOneWidget);
      expect(
        find.text("We've sent a 4-digit code to +91 98765 43210"),
        findsOneWidget,
      );
    });

    testWidgets('offers no country to change to', (tester) async {
      await _openLogin(tester, const Size(402, 874));

      // The app serves India, so +91 is a fixed prefix rather than a menu with
      // one item in it. Tapping it opens nothing and the number survives.
      // Deliberately not the sample number, which is on screen as the hint.
      await tester.enterText(find.byType(TextField), '9012345678');
      await tester.pump();

      await tester.tap(find.text('+91'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('90123 45678'), findsOneWidget);
    });

    testWidgets('back returns to the landing screen', (tester) async {
      await _openLogin(tester, const Size(402, 874));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text(AppBrand.name), findsOneWidget);
    });
  });
}
