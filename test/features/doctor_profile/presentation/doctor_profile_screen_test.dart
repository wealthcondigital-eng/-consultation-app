import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the doctor's profile must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _openProfile(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const TeleconsultApp(initialRoute: AppRoutes.doctorProfile),
  );
  await tester.pumpAndSettle();
}

/// Brings [target] into view, whether or not the list has built it yet.
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

  group('DoctorProfileScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openProfile(tester, entry.value);

        expect(tester.takeException(), isNull);
        // No top bar reading "Profile": the hero header names the screen by
        // showing whose it is.
        expect(find.text('Dr. Amit Verma'), findsOneWidget);
        expect(find.text('Cardiologist'), findsOneWidget);
        expect(find.text('PRACTICE'), findsOneWidget);

        await _scrollTo(tester, find.text('Logout'));
        expect(find.text('ACCOUNT'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('leads with who the doctor is, then what they can change', (
      tester,
    ) async {
      await _openProfile(tester, const Size(402, 874));

      // The title is dropped from the initials: every doctor has one.
      expect(find.text('AV'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      // Today's figures, restated from the dashboard.
      expect(find.text('4.8 ★'), findsOneWidget);

      // Availability is one setting among several here, not the whole screen.
      expect(find.text('Set Availability'), findsOneWidget);
      expect(find.text('Consultation Fees'), findsOneWidget);
      expect(find.text('Bank & Payouts'), findsOneWidget);
    });

    testWidgets('the rows carry the setting behind them', (tester) async {
      await _openProfile(tester, const Size(402, 874));

      expect(find.text('Mon-Fri · 3 slots'), findsOneWidget);
      // Both prices, because the row now has two to report. It used to show a
      // single amount because the screen behind it only collected one.
      expect(find.text('₹700 video · ₹400 audio'), findsOneWidget);
    });

    testWidgets('the availability row opens the schedule, and the summary '
        'follows what was saved', (tester) async {
      await _openProfile(tester, const Size(402, 874));

      await tester.tap(find.text('Set Availability'));
      await tester.pumpAndSettle();

      // Sunday joins the week, so the summary can no longer read `Mon-Fri`.
      await tester.tap(find.text('Sun'));
      await tester.pump();
      await tester.tap(find.text('Save Availability'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Mon-Fri, Sun · 3 slots'), findsOneWidget);
    });

    testWidgets('logging out clears the stack back to the landing screen', (
      tester,
    ) async {
      await _openProfile(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('Logout'));
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);

      await tester.tap(find.text('Log out'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Continue as Doctor'), findsOneWidget);
    });
  });
}
