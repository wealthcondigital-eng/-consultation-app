import 'package:consultation_app/features/anonymous/presentation/widgets/consult_language_field.dart';
import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/widgets/app_segmented_control.dart';
import 'package:consultation_app/features/consultation/domain/entities/consult_option.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/doctors/presentation/widgets/doctor_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the form must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _openBooking(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const TeleconsultApp(initialRoute: AppRoutes.anonymousBooking),
  );
  // Nothing animates while the suggested alias is in flight, so the clock is
  // advanced explicitly rather than left to pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _codeNameField() => find.byType(TextField).first;

/// The concern box: the only clinical context an anonymous consultation has,
/// and required because of it.
Finder _concernField() => find.byType(TextField).last;

/// Fills in everything the form needs to be submittable.
Future<void> _completeForm(
  WidgetTester tester, {
  String alias = 'Patient Hawk',
}) async {
  await tester.enterText(_codeNameField(), alias);
  await tester.pump();
  await tester.enterText(
    _concernField(),
    'Trouble sleeping and constant anxiety for about three weeks.',
  );
  await tester.pump();
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('AnonymousBookingScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openBooking(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Anonymous Booking'), findsOneWidget);
        expect(
          find.text('Your real identity will not be shared'),
          findsOneWidget,
        );
        expect(find.text('When'), findsOneWidget);
        expect(find.text('Now'), findsOneWidget);
        expect(find.text('Book a slot'), findsOneWidget);
        expect(find.text('Enter Your Code Name'), findsOneWidget);
        expect(find.text('Preferred Language'), findsOneWidget);
        expect(find.text('Describe your concern'), findsOneWidget);

        // Scrolled to rather than asserted in place. The form is longer than a
        // 320pt screen and always was — it scrolls by design, and a `ListView`
        // has not built the rows below the fold. Dragging is what distinguishes
        // "below the fold", which is fine, from "not on the screen at all",
        // which is what this assertion is for.
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();

        expect(find.text('Find a Doctor Anonymously'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('leaves the alias empty for the patient to choose', (
      tester,
    ) async {
      await _openBooking(tester, const Size(402, 874));

      final field = tester.widget<TextField>(_codeNameField());
      expect(field.controller?.text, isEmpty);
    });

    testWidgets('picks a language from the sheet', (tester) async {
      await _openBooking(tester, const Size(402, 874));

      await tester.tap(find.text('English').first);
      await tester.pumpAndSettle();
      expect(find.byType(ConsultLanguageSheet), findsOneWidget);
      expect(find.text('हिन्दी'), findsOneWidget);

      await tester.tap(find.text('हिन्दी'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsultLanguageSheet), findsNothing);
      expect(find.text('हिन्दी'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('offers no call type, because there is no choice', (
      tester,
    ) async {
      await _openBooking(tester, const Size(402, 874));

      // An anonymous consultation is a voice call, full stop: a video call
      // hands the doctor the patient's face, which undoes the alias and every
      // other promise this screen makes. It used to be one of two equal
      // segments, so the wrong one was a mis-tap away and could not be undone.
      expect(find.byType(AppSegmentedControl<ConsultationMode>), findsNothing);
      expect(
        find.textContaining('voice calls, so the doctor never sees your face'),
        findsOneWidget,
      );
    });

    testWidgets('offers now and a booked slot', (tester) async {
      await _openBooking(tester, const Size(402, 874));

      // Anonymity is a property of the consultation, not of how soon it
      // happens. Until this was here the only way to book an appointment was
      // to give up the alias.
      final control = tester.widget<AppSegmentedControl<ConsultOptionKind>>(
        find.byType(AppSegmentedControl<ConsultOptionKind>),
      );

      expect(control.selected, ConsultOptionKind.instant);
    });

    testWidgets('an unusable alias blocks the booking and says why', (
      tester,
    ) async {
      await _openBooking(tester, const Size(402, 874));

      await tester.enterText(_codeNameField(), 'a');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find a Doctor Anonymously'));
      await tester.pumpAndSettle();

      expect(find.textContaining('at least 3 characters'), findsOneWidget);
      expect(find.text('Anonymous Booking'), findsOneWidget);
    });

    testWidgets('the concern is required, because it is all the doctor gets', (
      tester,
    ) async {
      await _openBooking(tester, const Size(402, 874));

      await tester.enterText(_codeNameField(), 'Patient Hawk');
      await tester.pump();

      // An alias tells the doctor nothing — no name, no history, no face. With
      // the concern left blank they would join knowing literally nothing about
      // who they are treating or why.
      await tester.tap(find.text('Find a Doctor Anonymously'));
      await tester.pump();

      expect(find.text('Anonymous Booking'), findsOneWidget);
      expect(
        find.text('Tell the doctor what you would like to discuss.'),
        findsOneWidget,
      );

      // A word is not context.
      await tester.enterText(_concernField(), 'sick');
      await tester.pump();
      expect(
        find.text('A little more detail helps the doctor prepare.'),
        findsOneWidget,
      );

      // And the error clears as soon as the entry becomes usable, rather than
      // sitting red until the next submit.
      await tester.enterText(
        _concernField(),
        'Trouble sleeping and constant anxiety for about three weeks.',
      );
      await tester.pump();
      expect(find.textContaining('helps the doctor prepare'), findsNothing);
    });

    testWidgets('booking now goes to doctors who can be paid for', (
      tester,
    ) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      await _openBooking(tester, const Size(402, 874));

      await _completeForm(tester);

      await tester.tap(find.text('Find a Doctor Anonymously'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Into the listing of doctors who are free right now — not straight into
      // matching, which is where this went until instant consultations started
      // being paid for.
      //
      // The reason is that "ring anybody" has no price. A consultation is
      // charged at the doctor's own fee, and they price video and audio
      // separately, so there is nothing to bill until there is a doctor. The
      // patient picks one, pays, and the listing rings them; the alias travels
      // the whole way and is still the only name the doctor is sent.
      expect(find.byType(DoctorListCard), findsAtLeastNWidgets(1));
      expect(find.text('Finding you the best doctor...'), findsNothing);

      // And the form is behind it, so back does not return to a filed booking.
      expect(find.text('Anonymous Booking'), findsNothing);
    });

    testWidgets('replaces itself, so back does not return to a filed booking', (
      tester,
    ) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      await _openBooking(tester, const Size(402, 874));

      await _completeForm(tester);

      await tester.tap(find.text('Find a Doctor Anonymously'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // `pushReplacementNamed`: the consultation is already filed by the time
      // the search screen appears, so going back to the form would offer to
      // file a second one.
      expect(find.text('Anonymous Booking'), findsNothing);
    });
  });
}
