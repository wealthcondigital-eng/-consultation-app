import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:consultation_app/features/scheduling/presentation/screens/schedule_consultation_screen.dart';
import 'package:consultation_app/features/scheduling/presentation/widgets/booking_summary_card.dart';
import 'package:consultation_app/features/scheduling/presentation/widgets/consultation_type_picker.dart';
import 'package:consultation_app/features/scheduling/presentation/widgets/schedule_date_strip.dart';
import 'package:consultation_app/features/scheduling/presentation/widgets/slot_period_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _doctor = Doctor(
  id: 'helen-ramirez',
  name: 'Dr. Helen Ramirez',
  speciality: 'Consultant Cardiologist',
  yearsOfExperience: 12,
  rating: 4.9,
  consultationFee: 800,
  audioConsultationFee: 600,
  isVerified: true,
  isAvailableNow: true,
);

/// Screens the schedule page must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _openSchedule(
  WidgetTester tester,
  Size size, {
  ConsultationMode mode = ConsultationMode.video,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TeleconsultApp(
      initialRoute: AppRoutes.scheduleConsultation,
      initialRouteArguments: ScheduleConsultationArgs(
        doctor: _doctor,
        mode: mode,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps a widget that may be below the fold on a phone-sized viewport.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _confirmButton() => find.widgetWithText(FilledButton, 'Confirm Booking');

/// Opens the screen and moves to the **second** day on the strip.
///
/// Only the first day can be a partial one: slots that have already passed are
/// not offered, so a suite running at two in the afternoon sees no morning on
/// today and one running at nine sees all of it. Every assertion below about a
/// specific time — `09:00`, both period groups — was written against a whole
/// day, and was quietly a test of what hour the suite ran at.
///
/// The second card is always a full day, which makes those assertions mean
/// what they say. That today drops its passed slots is covered deterministically
/// in `schedule_builder_test.dart`, where `now` can be set.
Future<void> _openOnAWholeDay(WidgetTester tester, Size size) async {
  await _openSchedule(tester, size);

  final days = find.descendant(
    of: find.byType(ScheduleDateStrip),
    matching: find.byType(InkWell),
  );

  await _tap(tester, days.at(1));
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('ScheduleConsultationScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openSchedule(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Schedule Consultation'), findsOneWidget);
        expect(find.text('Dr. Helen Ramirez'), findsOneWidget);
        expect(find.text('SELECT DATE'), findsOneWidget);
        expect(find.byType(ScheduleDateStrip), findsOneWidget);
        expect(find.text('AVAILABLE TIME SLOTS'), findsOneWidget);
        // At least one: this is a layout sweep, and how many period groups
        // today has left depends on the hour the suite runs at.
        expect(find.byType(SlotPeriodGroup), findsAtLeastNWidgets(1));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.text('CONSULTATION TYPE'), findsOneWidget);
        expect(find.byType(BookingSummaryCard), findsOneWidget);
        expect(_confirmButton(), findsOneWidget);
      });
    }

    testWidgets('shows a spinner until the schedule arrives', (tester) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const TeleconsultApp(
          initialRoute: AppRoutes.scheduleConsultation,
          initialRouteArguments: ScheduleConsultationArgs(doctor: _doctor),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ScheduleDateStrip), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(ScheduleDateStrip), findsOneWidget);
    });

    testWidgets('never offers a day with nothing left on it', (tester) async {
      await _openSchedule(tester, const Size(402, 874));

      // This used to assert a TODAY chip unconditionally, which only held
      // because the stub pinned the day to midnight and published slots that
      // had already passed. Now that today drops off once its last slot has
      // gone, whether TODAY is there depends on the hour the suite runs at —
      // so what is checked is the invariant instead: the strip has days, and
      // TODAY, when it appears at all, is the first of them.
      //
      // The clock-dependent rule itself is covered deterministically in
      // `schedule_builder_test.dart`, where `now` can be set.
      expect(find.byType(ScheduleDateStrip), findsOneWidget);
      expect(find.text('AVAILABLE TIME SLOTS'), findsOneWidget);

      final today = find.text('TODAY');
      if (today.evaluate().isEmpty) return;

      expect(today, findsOneWidget);
      expect(
        tester.getTopLeft(today).dx,
        lessThan(tester.getSize(find.byType(ScheduleDateStrip)).width / 2),
        reason: 'today should be the soonest day, at the head of the strip',
      );
    });

    testWidgets('groups the slots into morning and afternoon', (tester) async {
      await _openOnAWholeDay(tester, const Size(402, 874));

      expect(find.text('Morning Slots'), findsOneWidget);
      expect(find.text('Afternoon Slots'), findsOneWidget);
      // The half-hourly grid, on a 12-hour clock without am/pm.
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('02:30'), findsOneWidget);
    });

    testWidgets('cannot book until a slot is picked', (tester) async {
      await _openOnAWholeDay(tester, const Size(402, 874));

      expect(find.text('Pick a time slot to continue'), findsOneWidget);
      expect(tester.widget<FilledButton>(_confirmButton()).onPressed, isNull);

      await _tap(tester, find.text('09:00'));

      expect(find.text('Pick a time slot to continue'), findsNothing);
      expect(
        tester.widget<FilledButton>(_confirmButton()).onPressed,
        isNotNull,
      );
    });

    testWidgets('the summary names the slot once one is chosen', (
      tester,
    ) async {
      await _openOnAWholeDay(tester, const Size(402, 874));

      expect(find.text('Appointment'), findsNothing);

      await _tap(tester, find.text('10:00'));

      expect(find.text('Appointment'), findsOneWidget);
      expect(find.textContaining('10:00 AM'), findsOneWidget);
      expect(find.text('30 minutes'), findsOneWidget);
    });

    testWidgets('changing the day clears the slot', (tester) async {
      await _openOnAWholeDay(tester, const Size(402, 874));

      await _tap(tester, find.text('09:00'));
      expect(find.text('Appointment'), findsOneWidget);

      // On to the next day again, which is what clears the choice.
      final days = find.descendant(
        of: find.byType(ScheduleDateStrip),
        matching: find.byType(InkWell),
      );
      await _tap(tester, days.at(2));

      expect(find.text('Appointment'), findsNothing);
      expect(tester.widget<FilledButton>(_confirmButton()).onPressed, isNull);
    });

    testWidgets('the call type carries in and can be changed', (tester) async {
      await _openSchedule(
        tester,
        const Size(402, 874),
        mode: ConsultationMode.audio,
      );

      expect(find.byType(ConsultationTypePicker), findsOneWidget);
      expect(find.text('Video Call'), findsOneWidget);
      expect(find.text('Voice Call'), findsOneWidget);
      // Priced for the audio call chosen before browsing.
      expect(find.text('₹600'), findsOneWidget);

      await _tap(tester, find.text('Video Call'));

      expect(find.text('₹800'), findsOneWidget);
    });

    testWidgets('confirming a booking opens payment', (tester) async {
      await _openOnAWholeDay(tester, const Size(402, 874));

      await _tap(tester, find.text('10:30'));
      await _tap(tester, _confirmButton());

      expect(find.text('Payment'), findsOneWidget);
      expect(find.textContaining('10:30 AM'), findsOneWidget);
    });
  });
}
