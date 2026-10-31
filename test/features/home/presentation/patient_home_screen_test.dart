import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/update/app_update_prompt.dart';
import 'package:consultation_app/core/update/app_update_controller.dart';
import 'package:consultation_app/core/widgets/exit_confirmation.dart';
import 'package:consultation_app/features/home/presentation/widgets/consult_consent_dialog.dart';
import 'package:consultation_app/features/home/presentation/widgets/doctor_card.dart';
import 'package:consultation_app/features/home/presentation/widgets/patient_nav_bar.dart';
import 'package:consultation_app/features/home/presentation/widgets/quick_action_card.dart';
import 'package:consultation_app/features/home/presentation/widgets/speciality_tile.dart';
import 'package:consultation_app/features/onboarding/domain/entities/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the home page must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _openHome(
  WidgetTester tester,
  Size size, {

  /// Which dashboard to open. Its own route now, not an argument to a shared
  /// one — that argument decided which of two apps you were in, and every
  /// navigation that forgot it landed a doctor in the patient dashboard.
  String route = AppRoutes.home,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(TeleconsultApp(initialRoute: route));
  await tester.pumpAndSettle();
}

/// Brings [target] into view in the dashboard's list.
///
/// Needed since the summary card and the recent-consultations section moved in
/// above the listings: a `ListView` builds lazily, so a section below the fold
/// simply does not exist to be found.
/// A tab on the bar, found by its semantics label.
///
/// Not by its text: the bar draws a label only on the **selected** tab now, so
/// an unselected one has nothing to match on. Its semantics still name it,
/// which is what a screen reader reads and what this taps.
Finder _tab(Type bar, String label) => find.descendant(
  of: find.byType(bar),
  matching: find.bySemanticsLabel(label),
);

/// Reads the consent popup to the end, ticks the box and agrees.
Future<void> _agree(WidgetTester tester) async {
  await tester.drag(
    find.byKey(ConsultConsentDialog.scrollKey),
    const Offset(0, -3000),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('I have read and understood'));
  await tester.pump();
  await tester.tap(find.text('I agree'));
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

  group('PatientHomeScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openHome(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Alexander'), findsOneWidget);
        expect(find.text('How can we help you today?'), findsOneWidget);
        expect(find.byType(QuickActionCard), findsNWidgets(2));
        expect(find.text('Anonymous consultation'), findsOneWidget);
        expect(find.text('Video consultation'), findsOneWidget);
        expect(find.byType(PatientNavBar), findsOneWidget);

        // Below the fold on a phone now, so scrolled to rather than asserted
        // in place. Still asserted: overflow shows up while scrolling too, and
        // `takeException` below is what catches it.
        // The patient's own specialities, not a fixed row of four. It was
        // headed "Popular Specialities" and was the same for everybody —
        // popular with nobody, and shown to somebody on the day they installed
        // the app as though it described them.
        await _scrollTo(tester, find.text('By speciality'));
        expect(find.text('By speciality'), findsOneWidget);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('shows a spinner until the feed arrives', (tester) async {
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
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(DoctorCard), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders every speciality from the feed', (tester) async {
      await _openHome(tester, const Size(402, 874));

      await _scrollTo(tester, find.byType(SpecialityTile).first);

      // Stress Management and Internal Medicine pinned first, then the
      // patient's own three, then the rest of the catalogue. The row scrolls
      // sideways, so the later tiles are built but past the edge.
      expect(find.byType(SpecialityTile), findsAtLeastNWidgets(4));
      for (final name in ['General', 'Dentist', 'Cardio']) {
        expect(find.text(name, skipOffstage: false), findsOneWidget);
      }
      final firstTile = find.byType(SpecialityTile).first;
      expect(
        find.descendant(
          of: firstTile,
          matching: find.text('Stress Management'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('lists no doctors on the home screen', (tester) async {
      await _openHome(tester, const Size(402, 874));

      // The roster used to sit at the foot of the dashboard under "Verified
      // Doctors" — a second, shorter doctor list one scroll below the
      // specialities that open the real one, showing whichever two the feed
      // happened to return. Choosing a doctor happens in the listing, where
      // there are filters and all of them.
      expect(find.byType(DoctorCard), findsNothing);
      expect(find.text('Verified Doctors'), findsNothing);
      expect(find.text('Dr. Sunita Rao'), findsNothing);
    });

    testWidgets('the dashboard greets, and nothing more', (tester) async {
      await _openHome(tester, const Size(402, 874));

      expect(find.textContaining('Good ', findRichText: true), findsOneWidget);
      expect(find.text('Alexander'), findsOneWidget);

      // The three running totals moved to the profile. They are a *record* —
      // nothing on them is actionable, and a figure for money spent is the
      // last thing somebody opening a health app to reach a doctor needs in
      // their way.
      expect(find.text('Consults'), findsNothing);
      expect(find.text('Doctors'), findsNothing);
      expect(find.text('Spent'), findsNothing);
      expect(find.text('₹4,200'), findsNothing);
    });

    testWidgets('Video consultation opens the consultation options', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      await tester.tap(find.text('Video consultation'));
      await tester.pumpAndSettle();
      await _agree(tester);

      expect(find.text('Instant Consultation'), findsOneWidget);
      expect(find.text('Scheduled Consultation'), findsOneWidget);
    });

    testWidgets('Anonymous consultation asks for consent every time', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      // The terms are shown, and I agree does nothing until the box is
      // ticked. Cancelling stays on home.
      await tester.tap(find.text('Anonymous consultation'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('do not include prescriptions'),
        findsOneWidget,
      );

      // At the end the box is there, but I agree waits for the tick.
      await tester.drag(
        find.byKey(ConsultConsentDialog.scrollKey),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      final agree = find.widgetWithText(FilledButton, 'I agree');
      expect(tester.widget<FilledButton>(agree).onPressed, isNull);
      await tester.tap(find.textContaining('I have read and understood'));
      await tester.pump();
      expect(tester.widget<FilledButton>(agree).onPressed, isNotNull);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(ConsultConsentDialog), findsNothing);
      expect(find.text('Anonymous Booking'), findsNothing);

      // And it asks again, box unticked, rather than remembering.
      await tester.tap(find.text('Anonymous consultation'));
      await tester.pumpAndSettle();
      await _agree(tester);

      expect(find.text('Anonymous Booking'), findsOneWidget);
      expect(
        find.text('Your real identity will not be shared'),
        findsOneWidget,
      );
    });

    testWidgets('both consent popups hint at scrolling whenever back at the top', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      for (final card in ['Video consultation', 'Anonymous consultation']) {
        await tester.tap(find.text(card).first);
        await tester.pumpAndSettle();

        // The terms run past the popup, so the hint is up.
        expect(find.text('Scroll to read all terms'), findsOneWidget);

        // A short swipe up is enough to clear it.
        await tester.drag(
          find.byKey(ConsultConsentDialog.scrollKey),
          const Offset(0, -60),
        );
        await tester.pumpAndSettle();
        expect(find.text('Scroll to read all terms'), findsNothing);

        // Back up at the top before agreeing, it says so again.
        await tester.drag(
          find.byKey(ConsultConsentDialog.scrollKey),
          const Offset(0, 300),
        );
        await tester.pumpAndSettle();
        expect(find.text('Scroll to read all terms'), findsOneWidget);

        // Agreed: no more nudging, even back at the top.
        await tester.drag(
          find.byKey(ConsultConsentDialog.scrollKey),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('I have read and understood'));
        await tester.pump();
        await tester.drag(
          find.byKey(ConsultConsentDialog.scrollKey),
          const Offset(0, 3000),
        );
        await tester.pumpAndSettle();
        expect(find.text('Scroll to read all terms'), findsNothing);

        await tester.tap(find.byTooltip('Cancel'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('the bar offers only the destinations that exist', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      // The invariant, not the count: every tab on the bar leads to a screen.
      // Appointments and Chat once sat here before either had one, so a third
      // of the bar said "coming soon" — which is what this guards against.
      // Chat is still absent for exactly that reason.
      expect(PatientTab.values, hasLength(3));
      expect(find.text('Chat'), findsNothing);

      for (final tab in PatientTab.values) {
        await tester.tap(_tab(PatientNavBar, tab.label));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('coming soon'), findsNothing);
        // The bar survives every tab, which is the point of hosting them as
        // bodies rather than pushing routes.
        expect(find.byType(PatientNavBar), findsOneWidget);
      }
    });

    testWidgets('switching tabs changes the body and keeps the bar', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      await tester.tap(_tab(PatientNavBar, PatientTab.profile.label));
      await tester.pumpAndSettle();

      // The profile names itself by showing whose it is; the top bar that
      // used to read "My Profile" above a photo of you is gone.
      expect(find.text('Alexander Wright'), findsWidgets);
      expect(find.byType(QuickActionCard), findsNothing);
      expect(find.byType(PatientNavBar), findsOneWidget);

      await tester.tap(_tab(PatientNavBar, PatientTab.home.label));
      await tester.pumpAndSettle();

      expect(find.byType(QuickActionCard), findsNWidgets(2));
    });

    testWidgets('back from another tab lands on the dashboard, then asks', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      await tester.tap(_tab(PatientNavBar, PatientTab.profile.label));
      await tester.pumpAndSettle();

      // The first back goes home, with no dialog.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(QuickActionCard), findsNWidgets(2));
      expect(find.byType(ExitAppDialog), findsNothing);

      // The second, on the dashboard, asks before closing; Stay keeps it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ExitAppDialog), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.byType(ExitAppDialog), findsNothing);
      expect(find.byType(QuickActionCard), findsNWidgets(2));
    });

    testWidgets('the doctor gets a different home altogether', (tester) async {
      await _openHome(
        tester,
        const Size(402, 874),
        route: AppRoutes.doctorHome,
      );

      // The doctor's dashboard, and none of the patient's chrome.
      expect(find.text('Dr. Amit Verma'), findsOneWidget);
      expect(find.text('Cardiologist'), findsOneWidget);
      expect(find.byType(PatientNavBar), findsNothing);
    });

    testWidgets('the search bar opens a search with the keyboard up', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      await tester.tap(find.bySemanticsLabel('Search doctors'));
      await tester.pumpAndSettle();

      // Not the "Verified Doctors" browse list: a search, focused.
      expect(find.text('Verified Doctors'), findsNothing);
      expect(find.text('Search'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.autofocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('no history tile on home; the nav bar has Appointments', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      expect(find.text('All consultations'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PatientNavBar),
          matching: find.bySemanticsLabel(PatientTab.appointments.label),
        ),
        findsOneWidget,
      );
    });

    testWidgets('By speciality sits right under the consult cards', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('By speciality'));
      final cards = tester.getTopLeft(find.text('Video consultation')).dy;
      final speciality = tester.getTopLeft(find.text('By speciality')).dy;
      expect(speciality, greaterThan(cards));
      // And the last consultation comes after it.
      await _scrollTo(tester, find.text('Last consultation'));
      final speciality2 = tester.getTopLeft(find.text('By speciality')).dy;
      final last = tester.getTopLeft(find.text('Last consultation')).dy;
      expect(last, greaterThan(speciality2));
    });

    testWidgets('an update raises the sheet once, Later moves it to profile', (
      tester,
    ) async {
      await _openHome(tester, const Size(402, 874));

      sl<AppUpdateController>().debugSet(AppUpdatePhase.available);
      await tester.pumpAndSettle();

      expect(find.byType(AppUpdateSheet), findsOneWidget);
      expect(find.text('A new version is ready'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateSheet), findsNothing);
      expect(sl<AppUpdateController>().isDismissed, isTrue);

      // Once per launch: a second notification does not raise it again.
      sl<AppUpdateController>().debugSet(AppUpdatePhase.available);
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateSheet), findsNothing);

      // And the profile now carries the offer.
      await tester.tap(find.bySemanticsLabel(PatientTab.profile.label).last);
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateCard), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
