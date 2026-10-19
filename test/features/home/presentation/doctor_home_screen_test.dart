import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/push/call_kit_bridge.dart';
import 'package:consultation_app/core/push/ring_readiness_probe.dart';
import 'package:consultation_app/core/widgets/app_button.dart';
import 'package:consultation_app/features/home/presentation/widgets/doctor_appointment_card.dart';
import 'package:consultation_app/features/home/presentation/widgets/doctor_nav_bar.dart';
import 'package:consultation_app/features/home/presentation/widgets/doctor_greeting_header.dart';
import 'package:consultation_app/features/home/presentation/widgets/presence_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ring_readiness_controller_test.dart' show FakeRingProbe;

/// Screens the doctor's home must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _openHome(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const TeleconsultApp(initialRoute: AppRoutes.doctorHome),
  );
  await tester.pumpAndSettle();
}

/// Brings [target] into view in the dashboard's list.
/// A tab on the bar, found by its semantics label.
///
/// Not by its text: the bar draws a label only on the **selected** tab now, so
/// an unselected one has nothing to match on. Its semantics still name it,
/// which is what a screen reader reads and what this taps.
Finder _tab(Type bar, String label) => find.descendant(
  of: find.byType(bar),
  matching: find.bySemanticsLabel(label),
);

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

  group('DoctorHomeScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openHome(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Dr. Amit Verma'), findsOneWidget);
        expect(find.text('Cardiologist'), findsOneWidget);
        expect(find.byType(PresenceDial), findsOneWidget);
        expect(find.byType(DoctorNavBar), findsOneWidget);

        // Today's statistics moved to the profile.
        expect(find.text("Today's Statistics"), findsNothing);

        await _scrollTo(tester, find.text('Upcoming Appointments'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('shows a spinner until the dashboard arrives', (tester) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const TeleconsultApp(initialRoute: AppRoutes.doctorHome),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(PresenceDial), findsOneWidget);
    });

    testWidgets('opens online, and says what that means', (tester) async {
      await _openHome(tester, const Size(402, 874));

      expect(find.text('Online'), findsOneWidget);
      expect(
        find.text('Patients can reach you for an instant consultation'),
        findsOneWidget,
      );
    });

    testWidgets('the dial answers a tap at once and holds after the save', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      await tester.tap(find.byType(PresenceDial));
      await tester.pump();

      // Optimistic: the spinner is showing but the state has already flipped.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Offline'), findsOneWidget);
      expect(
        find.text('Only booked appointments will reach you'),
        findsOneWidget,
      );

      await tester.tap(find.byType(PresenceDial));
      await tester.pumpAndSettle();

      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets(
      'an Accept on the phone’s ringing screen is sent to the server',
      (tester) async {
        await _openHome(tester, const Size(402, 874));

        // What the ringing screen hands over when the doctor taps Accept.
        sl<CallKitBridge>().accepted.value = 'c_1';
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The stand-in backend has no calls to accept, and says so — which is
        // the proof the home asked for this one rather than ignoring it.
        expect(
          find.text('Consultations need a connection to the server.'),
          findsOneWidget,
        );
        expect(sl<CallKitBridge>().accepted.value, isNull);

        // Let the snackbar run out, so no timer outlives the test.
        await tester.pump(const Duration(seconds: 10));
      },
    );

    group('a phone that will not ring with the app closed', () {
      late FakeRingProbe probe;

      setUp(() {
        probe = FakeRingProbe(
          applicable: {RingCheckKind.notifications, RingCheckKind.battery},
          satisfied: {RingCheckKind.notifications},
        );
        sl.registerLazySingleton<RingReadinessProbe>(() => probe);
      });

      testWidgets('says so under the dial, and the sheet fixes it', (
        tester,
      ) async {
        await _openHome(tester, const Size(402, 874));

        expect(
          find.text('Calls may not ring when the app is closed'),
          findsOneWidget,
        );
        expect(find.text('1 setting to fix on this phone'), findsOneWidget);

        await tester.tap(
          find.text('Calls may not ring when the app is closed'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Make sure calls ring'), findsOneWidget);
        expect(find.text('Remove battery restriction'), findsOneWidget);

        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();

        expect(probe.fixed, [RingCheckKind.battery]);
      });

      testWidgets('going Online opens the sheet by itself, once', (
        tester,
      ) async {
        await _openHome(tester, const Size(402, 874));

        // Offline, then back Online.
        await tester.tap(find.byType(PresenceDial));
        await tester.pumpAndSettle();
        expect(
          find.text('Calls may not ring when the app is closed'),
          findsNothing,
        );

        await tester.tap(find.byType(PresenceDial));
        await tester.pumpAndSettle();
        expect(find.text('Make sure calls ring'), findsOneWidget);

        // Dismissed, and round again: not a second time.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PresenceDial));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PresenceDial));
        await tester.pumpAndSettle();

        expect(find.text('Make sure calls ring'), findsNothing);
      });

      testWidgets('says nothing once the phone is set up', (tester) async {
        probe.satisfied.add(RingCheckKind.battery);

        await _openHome(tester, const Size(402, 874));

        expect(
          find.text('Calls may not ring when the app is closed'),
          findsNothing,
        );
      });
    });

    testWidgets('greets the doctor for the time of day', (tester) async {
      await _openHome(tester, const Size(402, 874));

      expect(
        find.textContaining(
          DoctorGreetingHeader.greetingFor(DateTime.now()),
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('counts what is ahead and what is done', (tester) async {
      await _openHome(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('Completed'));

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('342'), findsOneWidget);
    });

    testWidgets('lists the day\'s appointments, marking the anonymous one', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('Upcoming Appointments'));

      // Four: three today and one tomorrow. The dashboard no longer stops at
      // midnight.
      expect(find.byType(DoctorAppointmentCard), findsNWidgets(4));
      expect(find.text('Rahul Sharma'), findsOneWidget);
      // No fixed clock time asserted: the stub's schedule is relative to now,
      // because a demo opened in the afternoon used to show a morning that had
      // already happened — and a past slot now offers Start Call.
      expect(find.text('Video Consultation'), findsWidgets);
      expect(find.text('Waiting'), findsOneWidget);
      expect(find.text('Confirmed'), findsNWidgets(3));
      // The alias, and the lock that marks it as one.
      expect(find.text('Patient Hawk'), findsOneWidget);
      expect(find.byIcon(Icons.person_off_rounded), findsWidgets);

      // What the patient said they want to discuss. On an anonymous
      // consultation it is the only thing the doctor is told about them, and
      // the card used to show an alias, a time and nothing else.
      expect(
        find.text('Would like to discuss stress and anxiety management.'),
        findsOneWidget,
      );
    });

    testWidgets('a waiting patient can be joined, a later one only opened', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('Upcoming Appointments'));

      // Only the patient who is actually waiting gets Start Call. A booking on
      // a later day has no room to open, so the button says what it does — it
      // used to read "View" on a card the doctor could equally well have been
      // about to take a call from.
      expect(find.text('Start Call'), findsOneWidget);
      expect(find.text('Details'), findsNWidgets(3));
    });

    testWidgets('the schedule is cut into days, today first', (tester) async {
      await _openHome(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('Upcoming Appointments'));

      // The dashboard used to end at midnight, so a doctor with a clear
      // afternoon and a full Thursday opened the app to "Nothing booked".
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('3 consultations'), findsOneWidget);
      expect(find.text('1 consultation'), findsOneWidget);
    });

    testWidgets('tapping the patient opens who they are', (tester) async {
      await _openHome(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('Upcoming Appointments'));

      await tester.tap(find.text('Rahul Sharma').first);
      await tester.pumpAndSettle();

      // The concern is on screen immediately, because a doctor opening this
      // mid-decision must not wait on a request to read the reason.
      expect(
        find.text('Chest tightness when climbing stairs for the past week.'),
        findsWidgets,
      );
      // And the history underneath it, from the patient the id points at.
      expect(find.text('With you'), findsOneWidget);
    });

    testWidgets('an anonymous patient has no history to open', (tester) async {
      await _openHome(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('Upcoming Appointments'));

      await tester.tap(find.text('Patient Hawk').first);
      await tester.pumpAndSettle();

      // Said plainly rather than shown as an empty history, which reads as a
      // patient who has never consulted anybody. There is no id to fetch with,
      // and that is the promise rather than a gap.
      expect(find.text('With you'), findsNothing);
      expect(find.textContaining('booked anonymously'), findsOneWidget);
    });

    testWidgets('every appointment card puts its action in the same place', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('Upcoming Appointments'));

      // `AppButton`, not `FilledButton`: a joinable card draws a filled button
      // and a later one an outlined one, and the invariant being asserted is
      // where the action *lands*, not which variant it is.
      final buttons = find.descendant(
        of: find.byType(DoctorAppointmentCard),
        matching: find.byType(AppButton),
      );
      expect(buttons, findsNWidgets(4));

      // Same width and the same right edge, whichever label they carry.
      final rects = tester
          .widgetList<AppButton>(buttons)
          .indexed
          .map((entry) => tester.getRect(buttons.at(entry.$1)));
      expect(rects.map((rect) => rect.width).toSet(), hasLength(1));
      expect(rects.map((rect) => rect.right).toSet(), hasLength(1));
    });

    testWidgets('starting a call joins the consultation', (tester) async {
      await _openHome(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('Start Call'));
      await tester.tap(find.text('Start Call'));
      await tester.pumpAndSettle();

      // Start Call goes through `join`, which answers with the channel, this
      // device's peer id and which side dials — the three things the
      // appointment card does not carry and the app must not guess. On the stub
      // backend there is no second device to find, so it says so rather than
      // opening a room with nobody in it.
      expect(
        find.text('Consultations need a connection to the server.'),
        findsOneWidget,
      );
    });

    testWidgets('the bar offers only the destinations that exist', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      // The invariant, not the count: every tab on the bar leads to a screen.
      // Patients and Earnings once sat here before either had one, so half the
      // bar said "coming soon" — which is what this guards against.
      expect(DoctorTab.values, hasLength(4));

      for (final tab in DoctorTab.values) {
        // Scoped to the bar: `Patients` is also one of the day's stat cards.
        await tester.tap(_tab(DoctorNavBar, tab.label));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('coming soon'), findsNothing);
        // The bar survives every tab, which is the point of hosting them as
        // bodies rather than pushing routes.
        expect(find.byType(DoctorNavBar), findsOneWidget);
      }
    });

    testWidgets('the nav bar switches, and Profile is a tab of its own', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      await tester.tap(_tab(DoctorNavBar, DoctorTab.profile.label));
      await tester.pumpAndSettle();

      // The doctor's own details, not the availability form the tab used to
      // push, and the nav bar stays put because nothing was pushed at all.
      expect(find.text('Practice'.toUpperCase()), findsOneWidget);
      expect(find.text('Consultation Fees'), findsOneWidget);
      expect(find.byType(DoctorNavBar), findsOneWidget);
    });

    testWidgets('saving availability comes back to the profile', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      await tester.tap(_tab(DoctorNavBar, DoctorTab.profile.label));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set Availability'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Availability'));
      // The save is slower than a frame, and nothing animates while it runs.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Back where it was opened from, with the nav bar and the row that
      // opened it — not a reset stack, and not the dashboard.
      expect(find.byType(DoctorNavBar), findsOneWidget);
      expect(find.text('Set Availability'), findsOneWidget);
      expect(find.text('Save Availability'), findsNothing);
    });
  });
}
