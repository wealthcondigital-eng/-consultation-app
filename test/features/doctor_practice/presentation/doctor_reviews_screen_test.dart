import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the review list must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _open(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const TeleconsultApp(initialRoute: AppRoutes.doctorReviews),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('DoctorReviewsScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _open(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Patient Reviews'), findsOneWidget);
      });
    }

    testWidgets('names the patient who wrote it', (tester) async {
      await _open(tester, const Size(402, 874));

      // The doctor was there. A page of identical "Verified patient" headings
      // — which is what the public directory shows, and rightly — tells them
      // nothing about which consultation a complaint came from.
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Verified patient'), findsNothing);
    });

    testWidgets('leaves an anonymous patient anonymous', (tester) async {
      await _open(tester, const Size(402, 874));

      // The agreement was with the platform, not with the directory. Naming
      // them to the doctor afterwards is exactly the disclosure anonymous
      // consultations exist to prevent.
      expect(find.text('Anonymous user'), findsOneWidget);
    });

    testWidgets('averages only the reviews it is showing', (tester) async {
      await _open(tester, const Size(402, 874));

      // 5, 4 and 5 from the stub. The label says which average this is,
      // because the dashboard's counts every rating including the silent ones
      // and the two numbers legitimately differ.
      expect(find.text('4.7'), findsOneWidget);
      expect(find.text('From 3 written reviews'), findsOneWidget);
    });
  });
}
