import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/features/auth/presentation/widgets/otp_input.dart';
import 'package:consultation_app/features/doctor_onboarding/data/datasources/doctor_onboarding_remote_data_source.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/doctor_application.dart';
import 'package:consultation_app/features/doctor_onboarding/presentation/screens/set_availability_screen.dart';
import 'package:consultation_app/features/doctor_onboarding/presentation/widgets/availability_day_row.dart';
import 'package:consultation_app/features/doctor_onboarding/presentation/widgets/certificate_upload_card.dart';
import 'package:consultation_app/features/doctor_onboarding/presentation/widgets/setup_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the doctor journey must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

/// One frame, then enough time for the stubbed network and a route change.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Covers a save that is slower than a frame: the call itself, then the frames
/// the route it opens needs. `pumpAndSettle` cannot do this — nothing is
/// animating while the request is in flight, so it returns immediately.
Future<void> _settleSave(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await _settle(tester);
}

Future<void> _openRoute(
  WidgetTester tester,
  Size size,
  String route, {
  Object? arguments,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Screens in this flow run timers (the review watch, progress spinners), so
  // the tree is torn down explicitly at the end of each test.
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(
    TeleconsultApp(initialRoute: route, initialRouteArguments: arguments),
  );
  await _settle(tester);
}

Future<void> _openSetup(WidgetTester tester, Size size) =>
    _openRoute(tester, size, AppRoutes.doctorProfileSetup);

/// Brings [target] into view in the screen's list.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

/// One day in the availability screen's week row.
Finder _dayCell(String label) => find.descendant(
  of: find.byType(AvailabilityDayRow),
  matching: find.text(label),
);

/// Uploads a certificate and lands on the pre-filled details step.
Future<void> _uploadCertificate(WidgetTester tester) async {
  await tester.tap(find.text('Scan Document'));
  await tester.pump();
  // The parse takes a moment, then the screen moves itself on.
  await tester.pump(const Duration(seconds: 2));
  await _settle(tester);
}

/// Fills the payout form in with details that pass validation.
///
/// By position: the step lays its fields out in one column, in the order the
/// design shows them, and the optional UPI ID at the end is left blank.
/// Ticks one language. A certificate cannot say what a doctor speaks, so no
/// scan fills it, and the details step will not move on without one.
Future<void> _pickLanguage(WidgetTester tester) async {
  await _scrollTo(tester, find.text('English'));
  await tester.tap(find.text('English'));
  await _settle(tester);
}

Future<void> _fillBankDetails(WidgetTester tester) async {
  const values = [
    'Chase Bank',
    'Dr. Sarah Jenkins',
    '1234567890',
    'CHAS0123456',
  ];

  for (final (index, value) in values.indexed) {
    await tester.enterText(find.byType(TextField).at(index), value);
    await tester.pump();
  }
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('Entering the doctor journey', () {
    testWidgets('Continue as Doctor logs in, then opens the profile setup', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // The OTP screen's resend countdown ticks forever otherwise.
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      await tester.pumpWidget(const TeleconsultApp());
      await _settle(tester);

      await tester.tap(find.text('Continue as Doctor'));
      await _settle(tester);

      expect(find.text("Let's Get Started"), findsOneWidget);

      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await _settleSave(tester);

      expect(find.text('Enter OTP'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(OtpInput),
          matching: find.byType(TextField),
        ),
        '482137',
      );
      await _settleSave(tester);

      // A doctor's next step is their own registration, not a patient profile.
      expect(find.text('Doctor Profile Setup'), findsOneWidget);
      expect(find.text('Verify Credentials'), findsOneWidget);
    });
  });

  group('DoctorProfileSetupScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openSetup(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Doctor Profile Setup'), findsOneWidget);
        expect(find.text('Verify Credentials'), findsOneWidget);
        expect(find.byType(SetupStepper), findsOneWidget);
        for (final step in ['Upload & Verify', 'Details', 'Bank']) {
          expect(find.text(step), findsOneWidget);
        }
        expect(find.text('Upload Medical Certificate'), findsOneWidget);
        // No Skip. The certificate is what a reviewer decides on, so there is
        // nothing to skip to.
        expect(find.text('Skip'), findsNothing);

        await _scrollTo(tester, find.text('Upload PDF or Image'));
        expect(find.text('Scan Document'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('explains what the upload accepts', (tester) async {
      await _openSetup(tester, const Size(402, 874));

      expect(find.text('Supports PDF, JPG or PNG up to 10MB'), findsOneWidget);
      expect(
        find.textContaining('reads it and fills in your profile'),
        findsOneWidget,
      );
      expect(
        find.text('A medical certificate is required to register as a doctor.'),
        findsOneWidget,
      );
    });

    testWidgets('the certificate is required before the details step', (
      tester,
    ) async {
      await _openSetup(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('Continue'));

      // Disabled, not missing: the way forward is visible from the start, and
      // what unlocks it is obvious. It used to be skippable, so a registration
      // could be filed with no document a reviewer had ever seen.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text('Continue'));
      await _settle(tester);

      // Still on the upload step.
      expect(find.text('Verify Credentials'), findsOneWidget);
      expect(find.text('Professional Details'), findsNothing);
    });

    testWidgets('an incomplete details step is refused with reasons', (
      tester,
    ) async {
      await _openSetup(tester, const Size(402, 874));

      await _uploadCertificate(tester);

      // Everything the parse filled in, cleared again — so the step is
      // incomplete for the same reason it used to be after a Skip.
      for (final index in [0, 1]) {
        await tester.enterText(find.byType(TextField).at(index), '');
        await tester.pump();
      }

      await _pickLanguage(tester);
      await _scrollTo(tester, find.text('Continue to Bank Details'));
      await tester.tap(find.text('Continue to Bank Details'));
      await _settle(tester);

      // Still on the details step, with a reason under each field it cannot
      // accept. The step's own heading has been scrolled past and culled by
      // the list, so the errors are what this asserts on.
      expect(find.text('Enter the name on your certificate.'), findsOneWidget);
      expect(find.text('Enter your registration number.'), findsOneWidget);
      expect(find.text('Bank Payout Account'), findsNothing);
    });

    testWidgets('scanning fills the details in and ticks what was verified', (
      tester,
    ) async {
      await _openSetup(tester, const Size(402, 874));

      await _uploadCertificate(tester);

      expect(find.text('Professional Details'), findsOneWidget);
      expect(find.textContaining('auto-filled and validated'), findsOneWidget);
      // The parsed name reaches the field itself, not just the hint.
      final name = tester.widget<TextField>(find.byType(TextField).first);
      expect(name.controller?.text, 'Dr. Sarah Jenkins');
      expect(find.text('MD - General Medicine'), findsOneWidget);
      expect(find.text('REG-9920-A'), findsWidgets);
      expect(find.text('Internal Medicine'), findsOneWidget);
      // The register confirmed both text fields, which is where a tick fits;
      // the dropdowns keep their chevron.
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    });

    testWidgets('the upload card names the file it is holding', (tester) async {
      await _openSetup(tester, const Size(402, 874));

      await tester.tap(find.text('Upload PDF or Image'));
      await tester.pump();

      // Mid-parse: the card says what it is doing.
      expect(find.text('Reading your certificate…'), findsOneWidget);
      expect(find.byType(CertificateUploadCard), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await _settle(tester);
    });

    testWidgets('the stepper ticks the steps already behind the doctor', (
      tester,
    ) async {
      await _openSetup(tester, const Size(402, 874));

      await _uploadCertificate(tester);
      await _pickLanguage(tester);
      await _scrollTo(tester, find.text('Continue to Bank Details'));
      await tester.tap(find.text('Continue to Bank Details'));
      await _settle(tester);

      expect(find.text('Bank Payout Account'), findsOneWidget);
      // Upload and Details are done; Bank is where the doctor is.
      final stepper = find.byType(SetupStepper);
      expect(
        find.descendant(
          of: stepper,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('back steps through the wizard before leaving it', (
      tester,
    ) async {
      await _openSetup(tester, const Size(402, 874));

      await _uploadCertificate(tester);
      expect(find.text('Professional Details'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await _settle(tester);

      expect(find.text('Verify Credentials'), findsOneWidget);
    });

    testWidgets('back from the first step offers to leave for login', (
      tester,
    ) async {
      await _openSetup(tester, const Size(402, 874));

      await tester.tap(find.bySemanticsLabel('Back'));
      await _settle(tester);

      // It used to call `maybePop()`, which did nothing here — the screen is
      // pushed with `(route) => false`, so there was no route underneath and
      // the system gesture closed the app instead.
      expect(find.text('Leave registration?'), findsOneWidget);
      expect(find.text('Leave and sign out'), findsOneWidget);

      await tester.tap(find.text('Keep registering'));
      await _settle(tester);

      expect(find.text('Verify Credentials'), findsOneWidget);
    });

    testWidgets('an incomplete payout form is refused with reasons', (
      tester,
    ) async {
      await _openSetup(tester, const Size(402, 874));

      await _uploadCertificate(tester);
      await _pickLanguage(tester);
      await _scrollTo(tester, find.text('Continue to Bank Details'));
      await tester.tap(find.text('Continue to Bank Details'));
      await _settle(tester);

      await _scrollTo(tester, find.text('Complete Registration'));
      await tester.tap(find.text('Complete Registration'));
      await _settle(tester);

      expect(find.text('Bank Payout Account'), findsOneWidget);
      expect(find.text('Enter your bank name.'), findsOneWidget);
      expect(find.text('Enter your account number.'), findsOneWidget);
    });

    testWidgets('a complete registration is filed and goes under review', (
      tester,
    ) async {
      await _openSetup(tester, const Size(402, 874));

      await _uploadCertificate(tester);
      await _pickLanguage(tester);
      await _scrollTo(tester, find.text('Continue to Bank Details'));
      await tester.tap(find.text('Continue to Bank Details'));
      await _settle(tester);

      await _fillBankDetails(tester);

      await _scrollTo(tester, find.text('Complete Registration'));
      await tester.tap(find.text('Complete Registration'));
      await _settleSave(tester);

      expect(find.text('Registration Submitted!'), findsOneWidget);
      expect(find.textContaining('under verification'), findsOneWidget);
    });
  });

  group('ApplicationPendingScreen', () {
    final application = DoctorApplication(
      id: 'application-1',
      status: DoctorApplicationStatus.underReview,
      submittedAt: DateTime(2026, 8, 12),
    );

    testWidgets('waits, then moves itself on once the board approves', (
      tester,
    ) async {
      await _openRoute(
        tester,
        const Size(402, 874),
        AppRoutes.doctorApplicationPending,
        arguments: application,
      );

      expect(find.text('Registration Submitted!'), findsOneWidget);

      await tester.pump(FakeDoctorOnboardingRemoteDataSource.reviewDuration);
      await _settle(tester);

      expect(find.text('Congratulations!'), findsOneWidget);
      expect(find.text('Complete Setup'), findsOneWidget);
      expect(find.text('Do it Later'), findsOneWidget);
    });
  });

  group('ApplicationApprovedScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openRoute(
          tester,
          entry.value,
          AppRoutes.doctorApplicationApproved,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Congratulations!'), findsOneWidget);
        expect(find.textContaining('verified successfully'), findsOneWidget);
      });
    }

    testWidgets('Complete Setup opens the fee step of the wizard', (
      tester,
    ) async {
      await _openRoute(
        tester,
        const Size(402, 874),
        AppRoutes.doctorApplicationApproved,
      );

      await tester.tap(find.text('Complete Setup'));
      await _settle(tester);

      expect(find.text('Setup Wizard'), findsOneWidget);
      expect(find.text('Consultation Fees'), findsOneWidget);
      expect(find.text('60% Completed'), findsOneWidget);
      // Two prices, not one. The step used to collect a single amount and
      // write it to both, so a voice call cost the same as a video one.
      expect(find.text('Video consultation'), findsOneWidget);
      expect(find.text('Audio consultation'), findsOneWidget);
      // Seeded with the platform's suggestions, which differ.
      expect(find.text('₹700 video · ₹400 audio'), findsOneWidget);
    });

    testWidgets('Do it Later goes straight into the doctor app', (
      tester,
    ) async {
      await _openRoute(
        tester,
        const Size(402, 874),
        AppRoutes.doctorApplicationApproved,
      );

      await tester.tap(find.text('Do it Later'));
      await _settle(tester);

      // The doctor's own home, with its presence dial.
      expect(find.text('Dr. Amit Verma'), findsOneWidget);
      expect(find.text('Cardiologist'), findsOneWidget);
      expect(find.text('Congratulations!'), findsNothing);

      // The home's notification bell starts its first load on arrival; let
      // it land so no timer outlives the test.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('PracticeSetupScreen', () {
    testWidgets('picking a fee updates the summary and carries on to '
        'availability', (tester) async {
      await _openRoute(
        tester,
        const Size(402, 874),
        AppRoutes.doctorPracticeSetup,
        // `true` marks it as a wizard step, which is what makes Continue carry
        // on rather than come back. The screen is told instead of guessing
        // from the navigator stack, which was true either way.
        arguments: true,
      );

      // The video field's chips come first, so its ₹1000 is the first match.
      await tester.tap(find.text('₹1000').first);
      await tester.pump();

      expect(find.text('₹1000 video · ₹400 audio'), findsOneWidget);

      await _scrollTo(tester, find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await _settleSave(tester);

      expect(find.text('Set Availability'), findsOneWidget);
    });

    testWidgets('Skip for now moves on without saving a fee', (tester) async {
      await _openRoute(
        tester,
        const Size(402, 874),
        AppRoutes.doctorPracticeSetup,
        // Skip only exists in the wizard: opened from the profile, a doctor
        // came to change a price and "skip" would just be a second Back.
        arguments: true,
      );

      await _scrollTo(tester, find.text('Skip for now'));
      await tester.tap(find.text('Skip for now'));
      await _settle(tester);

      expect(find.text('Set Availability'), findsOneWidget);
    });
  });

  group('SetAvailabilityScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openRoute(tester, entry.value, AppRoutes.doctorAvailability);

        expect(tester.takeException(), isNull);
        expect(find.text('Online Status'), findsOneWidget);
        expect(find.text('Select Days'), findsOneWidget);
        expect(find.text('Active Time Slots'), findsOneWidget);
        expect(find.text('3 selected'), findsOneWidget);

        // Pinned below the list rather than sitting under it, so it is on
        // screen on the shortest device in the table.
        expect(find.text('Save Availability'), findsOneWidget);

        await _scrollTo(tester, find.text('Add Custom Time'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the day and slot chips toggle, and the count follows', (
      tester,
    ) async {
      await _openRoute(
        tester,
        const Size(402, 874),
        AppRoutes.doctorAvailability,
      );

      await tester.tap(_dayCell('Sat'));
      await tester.pump();
      await tester.tap(find.text('11:00 AM - 12:00 PM'));
      await tester.pump();

      expect(find.text('4 selected'), findsOneWidget);

      await tester.tap(find.text('11:00 AM - 12:00 PM'));
      await tester.pump();

      expect(find.text('3 selected'), findsOneWidget);
    });

    testWidgets('a quick pick replaces the day selection, and undoes itself', (
      tester,
    ) async {
      await _openRoute(
        tester,
        const Size(402, 874),
        AppRoutes.doctorAvailability,
      );

      await tester.tap(find.text('Weekends'));
      await tester.pump();

      expect(find.text('Sat, Sun'), findsOneWidget);

      // The same tap again clears it, and the bar says what is missing.
      await tester.tap(find.text('Weekends'));
      await tester.pump();

      expect(find.text('Pick at least one day.'), findsOneWidget);
    });

    testWidgets('a custom window is added from the sheet, and can be removed', (
      tester,
    ) async {
      await _openRoute(
        tester,
        const Size(402, 874),
        AppRoutes.doctorAvailability,
      );

      await _scrollTo(tester, find.text('Add Custom Time'));
      await tester.tap(find.text('Add Custom Time'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add 8:00 AM - 9:00 AM'));
      await tester.pumpAndSettle();

      expect(find.text('8:00 AM - 9:00 AM'), findsOneWidget);
      expect(find.text('4 selected'), findsOneWidget);

      // A window added by mistake used to be stuck in the list for good.
      await tester.tap(find.bySemanticsLabel('Remove 8:00 AM - 9:00 AM'));
      await tester.pump();

      expect(find.text('8:00 AM - 9:00 AM'), findsNothing);
      expect(find.text('3 selected'), findsOneWidget);
    });

    testWidgets('a schedule with no days cannot be saved', (tester) async {
      await _openRoute(
        tester,
        const Size(402, 874),
        AppRoutes.doctorAvailability,
      );

      for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
        // Scoped to the day row: the heading beside it also names the days
        // that are selected, so the last one left would match twice.
        await tester.tap(_dayCell(day));
        await tester.pump();
      }

      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save Availability'),
      );
      expect(save.onPressed, isNull);
      expect(find.text('Pick at least one day.'), findsOneWidget);
    });

    testWidgets('saving finishes onboarding and enters the doctor app', (
      tester,
    ) async {
      await _openRoute(
        tester,
        const Size(402, 874),
        AppRoutes.doctorAvailability,
        arguments: const SetAvailabilityArgs(isWizardStep: true),
      );

      await tester.tap(find.text('Save Availability'));
      await _settleSave(tester);

      expect(find.text('Dr. Amit Verma'), findsOneWidget);
      expect(find.text('Set Availability'), findsNothing);

      // The home's notification bell starts its first load on arrival; let
      // it land so no timer outlives the test.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('the wizard reaches the doctor app rather than the fee step', (
      tester,
    ) async {
      // The bug this closes. The screen decided where to go by asking
      // `navigator.canPop()`, which is **true** during onboarding because the
      // wizard pushes this on top of the fee screen — so finishing onboarding
      // saved the schedule and popped back to the fee step, which reads as a
      // save that did not work.
      await _openRoute(
        tester,
        const Size(402, 874),
        AppRoutes.doctorApplicationApproved,
      );

      await tester.tap(find.text('Complete Setup'));
      await _settle(tester);

      await _scrollTo(tester, find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await _settleSave(tester);

      expect(find.text('Set Availability'), findsOneWidget);

      await tester.tap(find.text('Save Availability'));
      await _settleSave(tester);

      expect(find.text('Dr. Amit Verma'), findsOneWidget);
      expect(find.text('Consultation Fees'), findsNothing);
      expect(find.text('Set Availability'), findsNothing);

      // The home's notification bell starts its first load on arrival; let
      // it land so no timer outlives the test.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('an offline doctor can clear their hours and save', (
      tester,
    ) async {
      await _openRoute(
        tester,
        const Size(402, 874),
        AppRoutes.doctorAvailability,
      );

      // Off first: hours are only required to go *online*.
      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
        await tester.tap(_dayCell(day));
        await tester.pump();
      }

      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save Availability'),
      );
      // Was permanently disabled: `canSave` required a day and a window
      // whatever the switch said, so turning yourself off could not be saved.
      expect(save.onPressed, isNotNull);
      expect(
        find.text('No hours set — you will not be offered calls'),
        findsOneWidget,
      );
    });
  });
}
