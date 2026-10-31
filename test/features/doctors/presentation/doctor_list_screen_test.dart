import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/doctors/domain/entities/speciality.dart';
import 'package:consultation_app/features/doctors/presentation/screens/doctor_list_screen.dart';
import 'package:consultation_app/features/doctors/presentation/widgets/doctor_list_card.dart';
import 'package:consultation_app/features/home/presentation/widgets/speciality_tile.dart';
import 'package:consultation_app/features/onboarding/domain/entities/user_role.dart';
import 'package:consultation_app/features/scheduling/presentation/widgets/schedule_date_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _cardiology = Speciality(
  id: 'cardiology',
  name: 'Cardio',
  practitionerTitle: 'Cardiologist',
  symbol: SpecialitySymbol.cardiology,
);

const _paediatrics = Speciality(
  id: 'paediatrics',
  name: 'Child',
  practitionerTitle: 'Pediatrician',
  symbol: SpecialitySymbol.paediatrics,
);

const _dentistry = Speciality(
  id: 'dentistry',
  name: 'Dental',
  practitionerTitle: 'Dental Surgeon',
  symbol: SpecialitySymbol.dentistry,
);

/// Screens the listing must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _openList(
  WidgetTester tester,
  Size size, {
  Speciality? speciality = _cardiology,
  ConsultationMode? mode,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TeleconsultApp(
      initialRoute: AppRoutes.doctorList,
      initialRouteArguments: DoctorListArgs(speciality: speciality, mode: mode),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _searchField() => find.byType(TextField);

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('DoctorListScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openList(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Cardiologists'), findsOneWidget);
        expect(find.text('Search Cardiologist'), findsOneWidget);
        for (final chip in ['All', 'Available Now', 'Fee: Low to High']) {
          expect(find.text(chip), findsOneWidget);
        }
        expect(find.byType(DoctorListCard), findsNWidgets(2));
        expect(find.text('Dr. Amit Verma'), findsOneWidget);
        expect(find.text('Senior Cardiologist'), findsOneWidget);
        expect(find.text('15 yrs Exp'), findsOneWidget);
        expect(find.text('₹800'), findsOneWidget);
        expect(find.text('Consultation Fee'), findsNWidgets(2));
      });
    }

    testWidgets('shows a spinner until the doctors arrive', (tester) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const TeleconsultApp(
          initialRoute: AppRoutes.doctorList,
          initialRouteArguments: DoctorListArgs(speciality: _cardiology),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(DoctorListCard), findsNWidgets(2));
    });

    testWidgets('search narrows the list', (tester) async {
      await _openList(tester, const Size(402, 874));

      await tester.enterText(_searchField(), 'sarah');
      await tester.pumpAndSettle();

      expect(find.byType(DoctorListCard), findsOneWidget);
      expect(find.text("Dr. Sarah D'Souza"), findsOneWidget);
      expect(find.text('Dr. Amit Verma'), findsNothing);
    });

    testWidgets('a search with no matches explains itself', (tester) async {
      await _openList(tester, const Size(402, 874));

      await tester.enterText(_searchField(), 'zzz');
      await tester.pumpAndSettle();

      expect(find.byType(DoctorListCard), findsNothing);
      expect(find.text('No doctors match your search.'), findsOneWidget);
    });

    testWidgets('Available Now filters to doctors who are on', (tester) async {
      await _openList(tester, const Size(402, 874), speciality: _paediatrics);

      await tester.tap(find.text('Available Now'));
      await tester.pumpAndSettle();

      expect(find.byType(DoctorListCard), findsOneWidget);
      expect(find.text('Dr. Sunita Rao'), findsOneWidget);
    });

    testWidgets('a chosen call type hides the doctors who do not take it', (
      tester,
    ) async {
      // Dr. Neha Gupta is video only, so an audio consult must not list her.
      await _openList(
        tester,
        const Size(402, 874),
        speciality: _dentistry,
        mode: ConsultationMode.audio,
      );

      expect(find.byType(DoctorListCard), findsNothing);
      expect(
        find.text('No doctor here is taking audio calls right now.'),
        findsOneWidget,
      );
    });

    testWidgets('Fee: Low to High reorders by fee', (tester) async {
      // The full listing, whose catalogue order is not already sorted by fee —
      // otherwise the assertion would hold whether or not the sort ran.
      await _openList(tester, const Size(402, 874), speciality: null);

      List<int> fees() => tester
          .widgetList<DoctorListCard>(find.byType(DoctorListCard))
          .map((card) => card.doctor.consultationFee)
          .toList();

      expect(fees(), isNot(orderedEquals(fees()..sort())));

      // The chip row scrolls; the last chip sits off-screen on a phone.
      final chip = find.text('Fee: Low to High');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();

      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(fees(), [400, 500, 600, 800, 1000]);
    });

    testWidgets('booking asks how to consult, with a price for each', (
      tester,
    ) async {
      await _openList(tester, const Size(402, 874));

      await tester.tap(find.text('Book Appointment').first);
      await tester.pumpAndSettle();

      expect(find.text('How would you like to consult?'), findsOneWidget);
      // Dr. Amit Verma charges less for audio.
      expect(find.text('₹800'), findsWidgets);
      expect(find.text('₹600'), findsOneWidget);
    });

    testWidgets('choosing a mode opens the schedule priced for it', (
      tester,
    ) async {
      await _openList(tester, const Size(402, 874));

      await tester.tap(find.text('Book Appointment').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Audio Consultation'));
      await tester.pumpAndSettle();

      // The slot picker comes before payment for a booked appointment.
      expect(find.text('Schedule Consultation'), findsOneWidget);
      expect(find.text('Dr. Amit Verma'), findsOneWidget);
      // Dr. Amit Verma's audio fee, not the ₹800 video one.
      expect(find.text('₹600'), findsOneWidget);
    });

    testWidgets('a booked slot carries through to payment', (tester) async {
      await _openList(tester, const Size(402, 874));

      await tester.tap(find.text('Book Appointment').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Video Consultation'));
      await tester.pumpAndSettle();

      // On to the second day first. Only the first can be a partial one —
      // slots that have passed are not offered — so `09:00` is there or not
      // depending on the hour this suite runs at.
      final days = find.descendant(
        of: find.byType(ScheduleDateStrip),
        matching: find.byType(InkWell),
      );
      await tester.tap(days.at(1));
      await tester.pumpAndSettle();

      final slot = find.text('09:00');
      await tester.ensureVisible(slot);
      await tester.pumpAndSettle();
      await tester.tap(slot);
      await tester.pumpAndSettle();

      final confirm = find.widgetWithText(FilledButton, 'Confirm Booking');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.text('Payment'), findsOneWidget);
      // ₹800 video fee plus the ₹50 platform fee.
      expect(find.text('₹850'), findsOneWidget);
      // The chosen time is shown alongside who is being paid.
      expect(find.textContaining('09:00 AM'), findsOneWidget);
    });

    testWidgets('without a speciality it lists every doctor', (tester) async {
      await _openList(tester, const Size(402, 874), speciality: null);

      expect(find.text('Verified Doctors'), findsOneWidget);
      expect(find.text('Search doctors'), findsOneWidget);
      expect(find.byType(DoctorListCard), findsNWidgets(5));
    });

    testWidgets('a speciality tile on home opens its listing', (tester) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const TeleconsultApp(
          initialRoute: AppRoutes.home,
          initialRouteArguments: UserRole.patient,
        ),
      );
      await tester.pumpAndSettle();

      // Below the last consultation now, so scrolled to first.
      await tester.scrollUntilVisible(
        find.byType(SpecialityTile).first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Past the two pinned tiles and off the right edge of the row.
      await tester.ensureVisible(find.text('Cardio', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();

      expect(find.text('Cardiologists'), findsOneWidget);
      expect(find.byType(DoctorListCard), findsNWidgets(2));
    });
  });
}
