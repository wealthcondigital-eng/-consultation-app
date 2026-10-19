import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens each page must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _open(WidgetTester tester, String route, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(TeleconsultApp(initialRoute: route));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('the pages Play and the DPDP Act require', () {
    const pages = <String, String>{
      AppRoutes.dataProtection: 'Data Protection Notice',
      AppRoutes.privacyPolicy: 'Privacy Policy',
      AppRoutes.termsAndConditions: 'Terms & Conditions',
      AppRoutes.contactSupport: 'Contact Us',
      AppRoutes.deleteAccount: 'Delete Account',
    };

    for (final page in pages.entries) {
      for (final device in _devices.entries) {
        testWidgets('${page.value} lays out on ${device.key}', (tester) async {
          await _open(tester, page.key, device.value);

          expect(tester.takeException(), isNull);
          expect(find.text(page.value), findsWidgets);
        });
      }
    }

    testWidgets('every policy says when it was last updated', (tester) async {
      // A policy with no date on it is one nobody can tell they have already
      // read, and a reviewer cannot tell has been maintained.
      for (final route in [
        AppRoutes.dataProtection,
        AppRoutes.privacyPolicy,
        AppRoutes.termsAndConditions,
      ]) {
        await _open(tester, route, const Size(402, 874));
        expect(find.textContaining('Last updated'), findsOneWidget);
      }
    });

    testWidgets('the terms lead with the emergency warning', (tester) async {
      await _open(tester, AppRoutes.termsAndConditions, const Size(402, 874));

      // First, because it is the one section where the right answer is to stop
      // using the app and call an ambulance.
      expect(find.text('This is not emergency care'), findsOneWidget);
    });

    testWidgets('support names a route for data complaints', (tester) async {
      await _open(tester, AppRoutes.contactSupport, const Size(402, 874));

      // The Act asks for a named contact for grievances, kept apart from
      // ordinary support so a complaint about data handling does not land in a
      // queue about login problems.
      expect(find.text('Grievance Officer'), findsOneWidget);
      expect(find.textContaining('In an emergency'), findsOneWidget);
    });
  });

  group('deleting an account', () {
    testWidgets('warns, and points to the notice for the detail', (
      tester,
    ) async {
      await _open(tester, AppRoutes.deleteAccount, const Size(402, 874));

      expect(find.text('This cannot be undone'), findsOneWidget);
      // What is kept, and the 24-hour wait, are in the notice rather than here.
      expect(find.text('What happens to your data'), findsOneWidget);
    });

    testWidgets('the button asks again before anything is deleted', (
      tester,
    ) async {
      await _open(tester, AppRoutes.deleteAccount, const Size(402, 874));

      await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await tester.pumpAndSettle();

      expect(find.text('Delete your account?'), findsOneWidget);

      // Backing out leaves the account, and the screen, as they were.
      await tester.tap(find.text('Keep my account'));
      await tester.pumpAndSettle();

      expect(find.text('Delete your account?'), findsNothing);
      expect(find.text('This cannot be undone'), findsOneWidget);
    });
  });
}
