import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/features/appointments/domain/entities/appointment.dart';
import 'package:consultation_app/features/appointments/presentation/widgets/appointment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the appointment list must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _open(
  WidgetTester tester,
  Size size, {
  String route = AppRoutes.patientAppointments,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(TeleconsultApp(initialRoute: route));
  await tester.pumpAndSettle();
}

/// Picks a kind from the type dropdown.
///
/// Scoped to the menu items: the cards carry the same words as a badge, so an
/// unqualified finder matches the row as well as the filter.
Future<void> _pickKind(WidgetTester tester, String label) async {
  await tester.tap(find.byType(PopupMenuButton<AppointmentKindFilter>));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(PopupMenuItem<AppointmentKindFilter>),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('AppointmentsScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _open(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('My Appointments'), findsOneWidget);
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Upcoming'), findsOneWidget);
        expect(find.text('Past'), findsOneWidget);
        expect(find.byType(AppointmentCard), findsAtLeastNWidgets(1));
      });
    }

    testWidgets('names the doctor on the patient list', (tester) async {
      await _open(tester, const Size(402, 874));

      // From `FakeAppointmentRemoteDataSource`.
      expect(find.text('Dr. Sunita Rao'), findsOneWidget);
      expect(find.text('Pediatrician'), findsOneWidget);
      // Never the patient's own name — the whole point of `counterpartName`.
      expect(find.text('Rahul Sharma'), findsNothing);
    });

    testWidgets('names the patient on the doctor list', (tester) async {
      await _open(
        tester,
        const Size(402, 874),
        route: AppRoutes.doctorAppointments,
      );

      expect(find.text('Consultations'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      // The same rows read from the other end: no doctor names here.
      expect(find.text('Dr. Sunita Rao'), findsNothing);
    });

    testWidgets('offers a rejoin only on a consultation that is still live', (
      tester,
    ) async {
      await _open(tester, const Size(402, 874));

      // The screen opens on Upcoming, which is what a patient comes here for.
      // A finished consultation carrying a room is a room somebody could walk
      // back into, so the API withholds the channel and the button does not
      // appear — and a completed row is not in this timeframe at all.
      expect(find.text('Rejoin call'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Consultation done'), findsNothing);
    });

    testWidgets('the timeframe narrows the list', (tester) async {
      await _open(tester, const Size(402, 874));

      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('In progress'), findsNothing);
      expect(find.text('Consultation done'), findsOneWidget);

      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();

      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Consultation done'), findsNothing);
    });

    testWidgets('the rows are cut into days', (tester) async {
      await _open(tester, const Size(402, 874));

      // Headed by *when*, which is what a list of consultations is read for.
      // It used to be headed by kind — a property already on every card and
      // already a filter above the list, which left the reader working out
      // which of three timestamps was this afternoon.
      expect(find.textContaining('consultation'), findsWidgets);

      // The stub puts one row on today, so the relative heading is the one
      // that has to render. A date would be right too, and much less useful.
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('the type dropdown narrows the list', (tester) async {
      await _open(tester, const Size(402, 874));

      await _pickKind(tester, 'Scheduled');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Dr. Anita Desai'), findsOneWidget);
      expect(find.text('Dr. Sunita Rao'), findsNothing);

      await _pickKind(tester, 'Instant');
      await tester.pumpAndSettle();

      expect(find.text('Dr. Sunita Rao'), findsOneWidget);
      expect(find.text('Dr. Anita Desai'), findsNothing);
    });

    testWidgets('a kind with nothing in it says so rather than going blank', (
      tester,
    ) async {
      await _open(tester, const Size(402, 874));

      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();

      await _pickKind(tester, 'Scheduled');
      await tester.pumpAndSettle();

      // Not "no consultations yet": there are past consultations, just none of
      // this kind, and saying otherwise is simply wrong.
      expect(find.text('No scheduled consultations'), findsOneWidget);
      expect(find.text('No past consultations'), findsNothing);
    });
  });
}
