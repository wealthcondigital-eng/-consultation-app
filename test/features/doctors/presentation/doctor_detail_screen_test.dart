import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:consultation_app/features/doctors/presentation/screens/doctor_detail_screen.dart';
import 'package:consultation_app/features/doctors/presentation/widgets/doctor_list_card.dart';
import 'package:consultation_app/features/home/presentation/widgets/speciality_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the profile must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

/// The listing row the screen opens from. Everything on it is shown at once
/// and the long form fills in behind.
const _doctor = Doctor(
  id: 'amit-verma',
  name: 'Dr. Amit Verma',
  speciality: 'Senior Cardiologist',
  yearsOfExperience: 15,
  rating: 4.9,
  consultationFee: 800,
  audioConsultationFee: 600,
  isVerified: true,
  isAvailableNow: true,
);

Future<void> _open(
  WidgetTester tester,
  Size size, {
  Doctor doctor = _doctor,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TeleconsultApp(
      initialRoute: AppRoutes.doctorDetail,
      initialRouteArguments: DoctorDetailArgs(doctor: doctor),
    ),
  );
  await tester.pumpAndSettle();
  // The profile read is a plain delayed future, which schedules no frame — so
  // `pumpAndSettle` returns before it lands and the timer is still pending at
  // teardown. Covers the stub's latency explicitly.
  await tester.pump(const Duration(milliseconds: 400));
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

  group('DoctorDetailScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _open(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Dr. Amit Verma'), findsOneWidget);
        expect(find.text('Senior Cardiologist'), findsOneWidget);
        expect(find.text('Available now'), findsOneWidget);

        await _scrollTo(tester, find.text('CONSULTATION TYPES'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('opens on the row it was handed, before the profile lands', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const TeleconsultApp(
          initialRoute: AppRoutes.doctorDetail,
          initialRouteArguments: DoctorDetailArgs(doctor: _doctor),
        ),
      );
      await tester.pump();

      // No spinner over the whole page: everything needed to *recognise* the
      // doctor is already in hand, and a profile that spends a second as a
      // spinner is one people back out of before it arrives.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Dr. Amit Verma'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    });

    testWidgets('shows both fees, because they differ', (tester) async {
      await _open(tester, const Size(402, 874));

      // The listing shows one price. A doctor may charge less for a voice
      // call — which is what most patients want, and there was no way to find
      // out before committing to a mode.
      expect(find.text('₹800'), findsOneWidget);
      expect(find.text('₹600'), findsOneWidget);
    });

    testWidgets('fills in the description behind the row', (tester) async {
      await _open(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('ABOUT'));

      expect(find.textContaining('15 years of practice'), findsOneWidget);
      expect(find.text('QUALIFICATIONS'), findsOneWidget);
      expect(find.text('MBBS'), findsOneWidget);
      expect(find.text('SPEAKS'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('says which call types the doctor does not take', (
      tester,
    ) async {
      await _open(
        tester,
        const Size(402, 874),
        doctor: const Doctor(
          id: 'neha-gupta',
          name: 'Dr. Neha Gupta',
          speciality: 'Dental Surgeon',
          yearsOfExperience: 9,
          rating: 4.6,
          consultationFee: 500,
          isVerified: true,
          // A dentist needs to see the tooth.
          supportedModes: {ConsultationMode.video},
        ),
      );

      await _scrollTo(tester, find.text('CONSULTATION TYPES'));

      // Said outright rather than left out: a patient who wants a voice call
      // needs to know before the mode sheet refuses.
      expect(find.text('Audio Consultation'), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('an offline doctor can be booked but not rung', (tester) async {
      await _open(
        tester,
        const Size(402, 874),
        // An id the catalogue does not hold, so the profile read answers null
        // and the row this screen was handed is what stands. Presence is the
        // server's to report, and merging a fetched profile would overwrite it.
        doctor: const Doctor(
          id: 'off-shift',
          name: "Dr. Sarah D'Souza",
          speciality: 'Interventional Cardiologist',
          yearsOfExperience: 10,
          rating: 4.8,
          consultationFee: 1000,
        ),
      );

      expect(find.text('Currently offline'), findsOneWidget);

      // Offering Consult now would offer a call that times out, which is worse
      // than a disabled button beside a booking that will work.
      final consult = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Consult now'),
      );
      expect(consult.onPressed, isNull);
      expect(find.text('Book a slot'), findsOneWidget);

      // And the profile answers the question an offline doctor actually
      // raises. Before this, "when can I see you" meant opening the booking
      // grid and reading it.
      await _scrollTo(tester, find.text('NEXT AVAILABLE'));
      expect(find.text('NEXT AVAILABLE'), findsOneWidget);
      expect(find.text('Book'), findsWidgets);
    });

    testWidgets('a quoted time opens the booking screen already on it', (
      tester,
    ) async {
      await _open(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('NEXT AVAILABLE'));
      final firstSlot = find.ancestor(
        of: find.text('Book').first,
        matching: find.byType(InkWell),
      );

      await tester.tap(firstSlot.first);
      await tester.pumpAndSettle();

      // Landing on an unselected grid would throw the tap away and ask the
      // same question again.
      expect(find.text('Schedule Consultation'), findsOneWidget);
      expect(find.text('Appointment'), findsOneWidget);
    });

    testWidgets('a doctor in the listing leads here, not into a call', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const TeleconsultApp(initialRoute: AppRoutes.home),
      );
      await tester.pumpAndSettle();

      // Through a speciality tile, which is the only route from the dashboard
      // now: the home screen used to end in a second, shorter doctor list of
      // its own, and choosing a doctor belongs in the listing where there are
      // filters and all of them.
      await tester.scrollUntilVisible(
        find.byType(SpecialityTile).first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SpecialityTile).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DoctorListCard).first);
      await tester.pumpAndSettle();

      // Tapping a doctor used to file a consultation and ring them on the
      // spot, so there was no way to look at somebody without calling them —
      // and a mis-tap was a call to a stranger.
      expect(find.byType(DoctorDetailScreen), findsOneWidget);
      expect(find.text('Finding you the best doctor...'), findsNothing);
    });
  });
}
