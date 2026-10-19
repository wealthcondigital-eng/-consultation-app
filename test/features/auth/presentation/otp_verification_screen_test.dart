import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:consultation_app/features/auth/presentation/widgets/otp_input.dart';
import 'package:consultation_app/features/home/presentation/screens/patient_home_screen.dart';
import 'package:consultation_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the OTP page must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

/// Settles pending frames without burning through the resend cooldown, which
/// `pumpAndSettle` would do because the countdown reschedules every second.
Future<void> _settleTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Boots the app and walks to the OTP screen the way a user would.
Future<void> _openOtp(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Tearing the tree down disposes the controller, which cancels the resend
  // countdown. Without it every test would end with a timer still pending.
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(const TeleconsultApp());
  await _settleTransition(tester);

  await tester.tap(find.text('Continue as Patient'));
  await _settleTransition(tester);

  await tester.enterText(find.byType(TextField), '9876543210');
  await tester.pump();

  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  // Covers the stubbed network latency plus the route transition.
  await tester.pump(const Duration(milliseconds: 700));
  await _settleTransition(tester);
}

/// The single hidden field behind the six boxes. Scoped to [OtpInput] because
/// the login screen underneath keeps its own field in the tree.
Finder _codeField() => find.descendant(
  of: find.byType(OtpInput),
  matching: find.byType(TextField),
);

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('OtpVerificationScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openOtp(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('OTP Verification'), findsOneWidget);
        expect(find.text('Enter OTP'), findsOneWidget);
        expect(
          find.text("We've sent a 4-digit code to +91 98765 43210"),
          findsOneWidget,
        );
        expect(find.text('Resend OTP in'), findsOneWidget);
        expect(find.text('Verify & Proceed'), findsOneWidget);
      });
    }

    testWidgets('renders one box per digit', (tester) async {
      await _openOtp(tester, const Size(402, 874));

      expect(find.byType(OtpInput), findsOneWidget);

      await tester.enterText(_codeField(), '482');
      await tester.pump();

      for (final digit in ['4', '8', '2']) {
        expect(find.text(digit), findsOneWidget);
      }
    });

    testWidgets('Verify stays disabled until all four digits are in', (
      tester,
    ) async {
      await _openOtp(tester, const Size(402, 874));

      FilledButton verifyButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Verify & Proceed'),
      );

      expect(verifyButton().onPressed, isNull);

      await tester.enterText(_codeField(), '482');
      await tester.pump();
      expect(verifyButton().onPressed, isNull);
    });

    testWidgets('completing the code submits without a tap', (tester) async {
      await _openOtp(tester, const Size(402, 874));

      await tester.enterText(_codeField(), '4821');
      await tester.pump();

      // The label is swapped for the spinner while verification runs.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Verify & Proceed'), findsNothing);

      // Let the in-flight request finish so no timer outlives the test.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
    });

    testWidgets('counts down and then offers a resend', (tester) async {
      await _openOtp(tester, const Size(402, 874));

      expect(find.text('00:30'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:28'), findsOneWidget);

      // The stub answers with a 30-second cooldown, which is what the screen
      // now counts down — it used to count a constant compiled into the app,
      // regardless of what the server asked for.
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Resend OTP in'), findsNothing);
      expect(find.text('Resend OTP'), findsOneWidget);
    });

    testWidgets('a correct code verifies and clears the auth stack', (
      tester,
    ) async {
      await _openOtp(tester, const Size(402, 874));

      await tester.enterText(_codeField(), '4821');
      await tester.pump(const Duration(milliseconds: 700));
      // Safe to settle fully here: the removed route disposes the controller,
      // which cancels the countdown.
      await tester.pumpAndSettle();

      expect(find.text("Let's complete your profile"), findsOneWidget);
      // The auth screens are gone — nothing left to go back to.
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('a rejected code surfaces the error and stays put', (
      tester,
    ) async {
      await _openOtp(tester, const Size(402, 874));

      await tester.enterText(
        _codeField(),
        FakeAuthRemoteDataSource.rejectedCode,
      );
      await tester.pump(const Duration(milliseconds: 700));
      await _settleTransition(tester);

      expect(
        find.text('That code is incorrect. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Enter OTP'), findsOneWidget);
    });
  });

  group('OtpVerificationScreen · returning patient', () {
    setUp(() {
      // The default stub reports no stored profile, which is the first-time
      // path covered above. This one already has a record.
      sl.registerLazySingleton<ProfileRemoteDataSource>(
        () => _EnrolledProfileDataSource(),
      );
    });

    testWidgets('skips onboarding and lands on the dashboard', (tester) async {
      await _openOtp(tester, const Size(402, 874));

      await tester.enterText(_codeField(), '4821');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.byType(PatientHomeScreen), findsOneWidget);
      expect(find.text("Let's complete your profile"), findsNothing);
      // Nothing to go back to: the auth stack was cleared.
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });
}

/// A patient whose row already exists in the backend.
class _EnrolledProfileDataSource extends FakeProfileRemoteDataSource {
  // Not const: the stub it extends now holds the medical record and the photo
  // for the run, so saving one and reading it back agrees.
  _EnrolledProfileDataSource();

  @override
  Future<bool> hasProfile() async => true;
}
