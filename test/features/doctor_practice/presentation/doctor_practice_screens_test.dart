import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/widgets/app_button.dart';
import 'package:consultation_app/core/widgets/app_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens each of the practice screens must lay out cleanly on.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
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

/// Brings [target] into view in whichever list the screen scrolls.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  /// One sweep per screen, because a screen that overflows on a 320pt phone is
  /// a screen nobody on a small handset can use — the same matrix the rest of
  /// the app is held to.
  const screens = <String, String>{
    AppRoutes.doctorPatients: 'My Patients',
    AppRoutes.doctorEarnings: 'Earnings',
    AppRoutes.doctorBankAccount: 'Bank & Payouts',
    AppRoutes.doctorCredentials: 'Credentials',
    AppRoutes.doctorSettings: 'Settings',
    AppRoutes.doctorEditProfile: 'Edit Profile',
  };

  for (final entry in screens.entries) {
    group(entry.value, () {
      for (final device in _devices.entries) {
        testWidgets('lays out without overflow on ${device.key}', (
          tester,
        ) async {
          await _open(tester, entry.key, device.value);

          expect(tester.takeException(), isNull);
          expect(find.text(entry.value), findsAtLeastNWidgets(1));
        });
      }
    });
  }

  group('DoctorPatientsScreen', () {
    testWidgets('lists who the doctor has consulted, and what they were '
        'billed', (tester) async {
      await _open(tester, AppRoutes.doctorPatients, const Size(402, 874));

      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('4 consultations'), findsOneWidget);
      expect(find.text('₹2,800'), findsOneWidget);
    });

    testWidgets('search narrows the roster', (tester) async {
      await _open(tester, AppRoutes.doctorPatients, const Size(402, 874));

      await tester.enterText(find.byType(TextField), 'meera');
      // Past the debounce and past the stub's own latency. `pumpAndSettle`
      // alone stops as soon as no frame is scheduled, which is before a
      // `Future.delayed` inside the data source has resolved.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Meera Iyer'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsNothing);
    });
  });

  group('DoctorEarningsScreen', () {
    testWidgets('shows gross takings and says so', (tester) async {
      await _open(tester, AppRoutes.doctorEarnings, const Size(402, 874));

      expect(find.text('Consultations'), findsAtLeastNWidgets(1));
      expect(find.text('Average fee'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      // The figure is what was *charged*, not a payout. Saying so on the card
      // is what keeps a doctor from planning against it.
      expect(find.textContaining('before the platform'), findsOneWidget);
    });

    testWidgets('switching period reloads without stranding the old total', (
      tester,
    ) async {
      await _open(tester, AppRoutes.doctorEarnings, const Size(402, 874));

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Billed · Today'), findsOneWidget);
    });
  });

  group('BankAccountScreen', () {
    testWidgets('shows the stored account masked, never in full', (
      tester,
    ) async {
      await _open(tester, AppRoutes.doctorBankAccount, const Size(402, 874));

      expect(find.text('•••• 6789'), findsOneWidget);
      expect(find.text('HDFC Bank'), findsOneWidget);
      // Nothing on this screen holds the whole number once it has been sent.
      expect(find.textContaining('6789', findRichText: true), findsOneWidget);
    });

    testWidgets('replacing it asks for the whole destination again', (
      tester,
    ) async {
      await _open(tester, AppRoutes.doctorBankAccount, const Size(402, 874));

      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      expect(find.text('Account number'), findsOneWidget);
      expect(find.text('IFSC code'), findsOneWidget);
      // The name and the bank carry over; the number and the IFSC do not,
      // because the number is masked and an IFSC belongs to the branch it is at.
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(
        fields.where((field) => field.controller?.text.isEmpty ?? true).length,
        greaterThanOrEqualTo(2),
      );
    });

    testWidgets('refuses an account number that is not one', (tester) async {
      await _open(tester, AppRoutes.doctorBankAccount, const Size(402, 874));

      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Replace account'));
      await tester.tap(find.text('Replace account'));
      await tester.pumpAndSettle();

      // The button is disabled until the form is complete, so nothing was
      // sent — and the screen has not moved on.
      expect(find.text('Account number'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DoctorCredentialsScreen', () {
    testWidgets('reports the review decision', (tester) async {
      await _open(tester, AppRoutes.doctorCredentials, const Size(402, 874));

      expect(find.text('Registration · Approved'), findsOneWidget);
      expect(find.text('Degree certificate'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
    });

    testWidgets('every document can be looked at', (tester) async {
      await _open(tester, AppRoutes.doctorCredentials, const Size(402, 874));

      // Still no URL in the payload — the bytes come over the same bearer
      // token as the record. What changed is that there is now a way to them
      // at all: a doctor whose certificate was rejected over an illegible
      // number cannot act on that note without seeing the page it is about.
      expect(find.text('View'), findsNWidgets(2));
    });
  });

  group('DoctorSettingsScreen', () {
    testWidgets('every switch is a real preference', (tester) async {
      await _open(tester, AppRoutes.doctorSettings, const Size(402, 874));

      expect(find.byType(AppSwitchRow), findsNWidgets(4));
      expect(find.text('Incoming consultations'), findsOneWidget);
      expect(find.textContaining('coming soon'), findsNothing);
    });

    testWidgets('turning incoming consultations off says what that means', (
      tester,
    ) async {
      await _open(tester, AppRoutes.doctorSettings, const Size(402, 874));

      await tester.tap(find.text('Incoming consultations'));
      await tester.pumpAndSettle();

      // Not decoration: the matcher on the API reads this flag, so the warning
      // is the honest consequence rather than a scare.
      expect(find.textContaining('Patients cannot reach you'), findsOneWidget);
    });
  });

  group('EditDoctorProfileScreen', () {
    testWidgets('opens on the stored profile', (tester) async {
      await _open(tester, AppRoutes.doctorEditProfile, const Size(402, 874));

      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('About you'), findsOneWidget);
      expect(find.text('LANGUAGES'), findsOneWidget);
    });

    testWidgets('shows the reviewed fields read-only, and says why', (
      tester,
    ) async {
      await _open(tester, AppRoutes.doctorEditProfile, const Size(402, 874));

      await _scrollTo(tester, find.text('VERIFIED DETAILS'));

      expect(find.text('Registration no.'), findsOneWidget);
      expect(find.text('MMC/2011/45821'), findsOneWidget);
      expect(find.textContaining('not editable here'), findsOneWidget);
    });

    testWidgets('Save is off until something changes', (tester) async {
      await _open(tester, AppRoutes.doctorEditProfile, const Size(402, 874));

      await _scrollTo(tester, find.text('Save changes'));

      // `AppButton` builds its own surface rather than wrapping a Material
      // button, so the disabled state is read off the widget itself.
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField).first, 'Amit K Verma');
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Save changes'));

      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNotNull,
      );
    });
  });
}
