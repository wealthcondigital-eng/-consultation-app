import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/widgets/app_button.dart';
import 'package:consultation_app/core/widgets/app_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the medical-history form must lay out cleanly on.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _open(
  WidgetTester tester,
  Size size, {
  String route = AppRoutes.medicalHistory,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(TeleconsultApp(initialRoute: route));
  await tester.pumpAndSettle();
}

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

  group('MedicalHistoryScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _open(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Medical Records'), findsOneWidget);
        // Records first, then the optional note. The typed lists of
        // conditions, medication, allergies and procedures are gone — the
        // prescription says it better.
        expect(find.text('Medical records'), findsOneWidget);
        for (final label in ['CONDITIONS', 'MEDICATIONS', 'ALLERGIES']) {
          expect(find.text(label), findsNothing);
        }
        await _scrollTo(tester, find.text('NOTE FOR YOUR DOCTOR'));
        expect(find.text('NOTE FOR YOUR DOCTOR'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('records come before the note', (tester) async {
      await _open(tester, const Size(402, 874));

      final records = tester.getTopLeft(find.text('Medical records')).dy;
      await _scrollTo(tester, find.text('NOTE FOR YOUR DOCTOR'));
      final note = tester.getTopLeft(find.text('NOTE FOR YOUR DOCTOR')).dy;
      expect(records, lessThan(note));
    });

    testWidgets('names who reads it', (tester) async {
      await _open(tester, const Size(402, 874));

      expect(
        find.textContaining('Only a doctor in a consultation with you'),
        findsOneWidget,
      );
    });

    testWidgets('Save is off until the note changes', (tester) async {
      await _open(tester, const Size(402, 874));

      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );

      final field = find.byType(TextField).last;
      await _scrollTo(tester, field);
      await tester.enterText(field, 'Allergic to penicillin');
      await tester.pumpAndSettle();

      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('backing out of an edit asks first', (tester) async {
      await _open(tester, const Size(402, 874));

      final field = find.byType(TextField).last;
      await _scrollTo(tester, field);
      await tester.enterText(field, 'Allergic to penicillin');
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      // A medical record is tedious to type, and losing it to a stray
      // back-swipe is the kind of loss nobody comes back and redoes.
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      expect(find.text('Medical Records'), findsOneWidget);
    });
  });

  group('PatientSettingsScreen', () {
    testWidgets('every switch is a real preference', (tester) async {
      await _open(
        tester,
        const Size(402, 874),
        route: AppRoutes.patientSettings,
      );

      expect(find.byType(AppSwitchRow), findsNWidgets(4));
      expect(find.text('Consultation updates'), findsOneWidget);
      expect(find.text('Offers and health tips'), findsOneWidget);
      expect(find.textContaining('coming soon'), findsNothing);
    });

    testWidgets('marketing is off by default and consultation news is on', (
      tester,
    ) async {
      await _open(
        tester,
        const Size(402, 874),
        route: AppRoutes.patientSettings,
      );

      final rows = tester
          .widgetList<AppSwitchRow>(find.byType(AppSwitchRow))
          .toList();

      // A preference nobody set should be the one the person would have
      // chosen, and nobody opts into promotions by accident.
      expect(rows[0].value, isTrue, reason: 'consultation updates');
      expect(rows[1].value, isTrue, reason: 'chat messages');
      expect(rows[2].value, isFalse, reason: 'promotions');
      expect(rows[3].value, isFalse, reason: 'email updates');
    });

    testWidgets('a switch answers the tap immediately', (tester) async {
      await _open(
        tester,
        const Size(402, 874),
        route: AppRoutes.patientSettings,
      );

      await tester.tap(find.text('Offers and health tips'));
      await tester.pump();

      // Optimistic: the switch moves before the round trip, because one that
      // lags reads as broken and gets tapped again.
      final promotions = tester
          .widgetList<AppSwitchRow>(find.byType(AppSwitchRow))
          .elementAt(2);
      expect(promotions.value, isTrue);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('reports on the record', () {
    testWidgets('asks what the document is, then where it comes from', (
      tester,
    ) async {
      await _open(tester, const Size(402, 874));

      await tester.scrollUntilVisible(
        find.text('Medical records'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Nothing uploaded yet, so the panel says what a report is *for* rather
      // than that the list is empty — a patient who has never added one does
      // not know whether the doctor will actually read it.
      expect(find.text('Add a lab result or scan'), findsOneWidget);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // What it is comes first. The kind changes how a doctor reads the row,
      // and neither choice carries verification language — both sides may add
      // a prescription and nothing here approves one.
      expect(find.text('What are you adding?'), findsOneWidget);
      expect(find.text('Prescription'), findsOneWidget);
      expect(find.text('Report or document'), findsOneWidget);

      await tester.tap(find.text('Prescription'));
      await tester.pumpAndSettle();

      // Camera first: the common case by a distance is somebody holding a
      // printed result, and a flow that opens a file browser first sends them
      // away to photograph it themselves.
      expect(find.text('Add a prescription'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Choose a file'), findsOneWidget);
    });
  });
}
