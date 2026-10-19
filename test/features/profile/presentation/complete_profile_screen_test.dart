import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/widgets/app_checkbox.dart';
import 'package:consultation_app/features/onboarding/domain/entities/user_role.dart';
import 'package:consultation_app/features/profile/domain/entities/gender.dart';
import 'package:consultation_app/features/profile/presentation/screens/complete_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the profile form must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

/// Opens the screen directly. The auth flow ahead of it is covered by its own
/// tests, and starting here keeps the OTP countdown out of this file.
Future<void> _openProfile(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TeleconsultApp(
      initialRoute: AppRoutes.completeProfile,
      initialRouteArguments: UserRole.patient,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _nameField() => find.widgetWithText(TextField, 'e.g. Rahul Sharma');
Finder _dateField() => find.text('Select your date of birth');

/// Opens the date wheel and accepts what it opens on.
///
/// The sheet starts on the youngest eligible date — exactly eighteen today —
/// so confirming without scrolling picks a date that passes the gate.
Future<void> _pickEligibleDate(WidgetTester tester) async {
  await tester.tap(_dateField());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

/// Fills every field with something valid.
Future<void> _completeForm(WidgetTester tester) async {
  await tester.enterText(_nameField(), 'Rahul Sharma');
  await tester.pump();

  await _pickEligibleDate(tester);

  // The button, not the hint text inside it — the hint does not hit test.
  await tester.tap(find.byType(DropdownButton<Gender>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(Gender.male.label).last);
  await tester.pumpAndSettle();

  for (var index = 0; index < 2; index++) {
    await _tickCheckbox(tester, index);
  }
}

/// Taps the box itself rather than the row's centre — the centre of a consent
/// row lands on one of the embedded links, which is its own tap target.
Future<void> _tickCheckbox(WidgetTester tester, int index) async {
  final row = find.byType(AppCheckbox).at(index);
  await tester.tapAt(tester.getTopLeft(row) + const Offset(6, 8));
  await tester.pump();
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('CompleteProfileScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openProfile(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Complete Profile'), findsOneWidget);
        expect(find.text('Full Name'), findsOneWidget);
        expect(find.text('Date of Birth'), findsOneWidget);
        expect(find.text('Gender'), findsOneWidget);
        expect(find.text('Select Gender'), findsOneWidget);
        expect(find.byType(AppCheckbox), findsNWidgets(2));
        expect(find.text('Continue'), findsOneWidget);
      });
    }

    testWidgets('states the 18+ rule before anyone fills the form in', (
      tester,
    ) async {
      await _openProfile(tester, const Size(402, 874));

      expect(
        find.text('You must be 18 or older to open an account.'),
        findsOneWidget,
      );
    });

    testWidgets('asks for two consents, not three', (tester) async {
      await _openProfile(tester, const Size(402, 874));

      expect(find.byType(AppCheckbox), findsNWidgets(2));

      // A DPA is a contract with our processors, not something a patient signs.
      expect(find.textContaining('Data Processing Agreement'), findsNothing);
    });

    testWidgets('shows no errors before the first submit', (tester) async {
      await _openProfile(tester, const Size(402, 874));

      expect(find.text('Enter your full name.'), findsNothing);
      expect(find.text('Select your gender.'), findsNothing);
    });

    testWidgets('submitting an empty form reports every missing field', (
      tester,
    ) async {
      await _openProfile(tester, const Size(402, 874));

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your full name.'), findsOneWidget);
      expect(find.text('Select your date of birth.'), findsOneWidget);
      expect(find.text('Select your gender.'), findsOneWidget);
      expect(
        find.text('This consent is required to continue.'),
        findsOneWidget,
      );
      expect(
        find.text('You must accept the terms to continue.'),
        findsOneWidget,
      );
    });

    testWidgets('a field error clears as soon as it is fixed', (tester) async {
      await _openProfile(tester, const Size(402, 874));

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your full name.'), findsOneWidget);

      await tester.enterText(_nameField(), 'Rahul Sharma');
      await tester.pump();

      expect(find.text('Enter your full name.'), findsNothing);
    });

    testWidgets('a complete form saves and clears the onboarding stack', (
      tester,
    ) async {
      await _openProfile(tester, const Size(402, 874));
      await _completeForm(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Alexander'), findsOneWidget);
      expect(find.byType(CompleteProfileScreen), findsNothing);
      // Nothing left to go back to.
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });
}
