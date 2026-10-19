import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/branding/app_brand.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/features/home/presentation/widgets/patient_nav_bar.dart';
import 'package:consultation_app/features/onboarding/domain/entities/user_role.dart';
import 'package:consultation_app/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:consultation_app/features/profile/presentation/widgets/medical_history_card.dart';
import 'package:consultation_app/features/profile/presentation/widgets/profile_section.dart';
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

Future<void> _openProfile(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const TeleconsultApp(initialRoute: AppRoutes.patientProfile),
  );
  await tester.pumpAndSettle();
}

Future<void> _openHome(WidgetTester tester) async {
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
}

/// Brings [target] into view, whether or not the list has built it yet.
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
  await tester.scrollUntilVisible(target, 200, scrollable: _listView());
  await tester.pumpAndSettle();
}

Finder _listView() => find.byType(Scrollable).first;

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('PatientProfileScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openProfile(tester, entry.value);

        expect(tester.takeException(), isNull);
        // No top bar reading "My Profile": the hero header names the screen
        // by showing whose it is.
        expect(find.text('MY PROFILE'), findsNothing);
        // At least one: the name appears in the identity block and again as a
        // detail row, and which of the two is on screen depends on how much of
        // the list fits — this sweep runs from a 320pt phone to a 1366pt
        // tablet. Counting them would be asserting the viewport, not the
        // layout.
        expect(find.text('Alexander Wright'), findsAtLeastNWidgets(1));
        expect(find.text('MEDICAL HISTORY'), findsOneWidget);

        // Below the fold on a short device now that the medical card carries
        // its counts, so scrolled to rather than assumed visible. A ListView
        // builds lazily: a section off-screen does not exist to be found.
        await _scrollTo(tester, find.text('PERSONAL DETAILS'));
        expect(find.text('PERSONAL DETAILS'), findsOneWidget);
        expect(find.text('Alexander Wright'), findsAtLeastNWidgets(1));
        expect(
          find.text('alexander.wright@gmail.com'),
          findsAtLeastNWidgets(1),
        );

        await _scrollTo(tester, find.text('Logout'));
        expect(find.text('ACCOUNT'), findsOneWidget);
        expect(find.text('Logout'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('shows a spinner until the account arrives', (tester) async {
      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const TeleconsultApp(initialRoute: AppRoutes.patientProfile),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Alexander Wright'), findsAtLeastNWidgets(1));
    });

    testWidgets('falls back to initials while there is no photo', (
      tester,
    ) async {
      await _openProfile(tester, const Size(402, 874));

      expect(find.text('AW'), findsOneWidget);
    });

    testWidgets('leads the medical section with the records', (tester) async {
      await _openProfile(tester, const Size(402, 874));

      expect(find.byType(MedicalHistoryCard), findsOneWidget);
      expect(find.text('Medical records'), findsOneWidget);
      expect(find.text('Prescriptions, lab reports & scans'), findsOneWidget);
      // The typed condition lists are no longer summarised here.
      expect(find.text('2 conditions'), findsNothing);
      expect(find.text('Asthma & Seasonal Allergies'), findsNothing);
    });

    testWidgets('lists the personal details, last row without a rule', (
      tester,
    ) async {
      await _openProfile(tester, const Size(402, 874));

      await _scrollTo(tester, find.text('PERSONAL DETAILS'));

      const labels = [
        'Full Name',
        'Email',
        'Phone Number',
        'Date of Birth',
        'Gender',
        'Blood Group',
      ];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('+1 (555) 234-5678'), findsOneWidget);
      expect(find.text('May 18, 1991'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('O Positive (O+)'), findsOneWidget);

      final rows = tester
          .widgetList<ProfileDetailRow>(find.byType(ProfileDetailRow))
          .toList();
      expect(rows.length, labels.length);
      expect(rows.last.showDivider, isFalse);
    });

    testWidgets('My Appointments opens the consultation history', (
      tester,
    ) async {
      await _openProfile(tester, const Size(402, 874));

      final appointments = find.text('My Appointments');
      await _scrollTo(tester, appointments);
      await tester.tap(appointments);
      await tester.pumpAndSettle();

      // The route, not a snackbar. Every row on this card led to
      // "coming soon" before the screens behind them existed.
      expect(tester.takeException(), isNull);
      expect(find.textContaining('coming soon'), findsNothing);
      expect(find.text('My Appointments'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
    });

    testWidgets('Notifications opens the settings screen', (tester) async {
      await _openProfile(tester, const Size(402, 874));

      final notifications = find.text('Notifications');
      await _scrollTo(tester, notifications);
      await tester.tap(notifications);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Consultation updates'), findsOneWidget);
      expect(find.text('Offers and health tips'), findsOneWidget);
    });

    testWidgets('the medical card opens the record and folds back the save', (
      tester,
    ) async {
      await _openProfile(tester, const Size(402, 874));

      final edit = find.text('Prescriptions, lab reports & scans');
      await _scrollTo(tester, edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();

      // Would have caught a `pushNamed<MedicalHistory>` type-cast crash: the
      // route is built as `Route<dynamic>` unless the router types it.
      expect(tester.takeException(), isNull);
      expect(find.text('Medical Records'), findsOneWidget);
    });

    testWidgets('logging out asks first, and cancelling stays put', (
      tester,
    ) async {
      await _openProfile(tester, const Size(402, 874));

      final logout = find.text('Logout');
      await _scrollTo(tester, logout);
      await tester.tap(logout);
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);

      // The quiet option is the way out, and it names what staying means.
      await tester.tap(find.text('Stay signed in'));
      await tester.pumpAndSettle();

      expect(find.text('MEDICAL HISTORY'), findsOneWidget);
    });

    testWidgets('confirming the log out returns to the landing screen', (
      tester,
    ) async {
      await _openProfile(tester, const Size(402, 874));

      final logout = find.text('Logout');
      await _scrollTo(tester, logout);
      await tester.tap(logout);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(find.text(AppBrand.name), findsOneWidget);
      expect(find.text('Continue as Patient'), findsOneWidget);
      expect(find.text('MEDICAL HISTORY'), findsNothing);
    });

    testWidgets('the home avatar opens the profile', (tester) async {
      await _openHome(tester);

      // By its label: the header carries the bell and a search bar too.
      await tester.tap(find.bySemanticsLabel('Your profile'));
      await tester.pumpAndSettle();

      expect(find.text('MEDICAL HISTORY'), findsOneWidget);
    });

    testWidgets('the Profile tab keeps the nav bar and swaps the body', (
      tester,
    ) async {
      await _openHome(tester);

      await tester.tap(_tab(PatientNavBar, PatientTab.profile.label));
      await tester.pumpAndSettle();

      expect(find.text('MEDICAL HISTORY'), findsOneWidget);

      // The point of the tab: navigation stays put underneath the profile.
      expect(find.byType(PatientNavBar), findsOneWidget);
      // Nothing was pushed, so the top bar offers no way back — the nav bar is
      // how you leave.
      expect(find.bySemanticsLabel('Back'), findsNothing);

      await tester.tap(_tab(PatientNavBar, PatientTab.home.label));
      await tester.pumpAndSettle();

      expect(find.text('How can we help you today?'), findsOneWidget);
      expect(find.text('MEDICAL HISTORY'), findsNothing);
    });

    testWidgets('the home avatar selects the Profile tab too', (tester) async {
      await _openHome(tester);

      // By its label: the header carries the bell and a search bar too.
      await tester.tap(find.bySemanticsLabel('Your profile'));
      await tester.pumpAndSettle();

      expect(find.text('MEDICAL HISTORY'), findsOneWidget);
      expect(find.byType(PatientNavBar), findsOneWidget);
    });

    testWidgets('Edit opens the form with the stored details', (tester) async {
      await _openProfile(tester, const Size(402, 874));

      // Scoped to the Personal Details section: Medical History has an
      // Edit of its own now, and an unqualified finder matches both.
      final editDetails = find.descendant(
        of: find.ancestor(
          of: find.text('PERSONAL DETAILS'),
          matching: find.byType(ProfileSection),
        ),
        matching: find.text('Edit'),
      );

      await _scrollTo(tester, editDetails);
      await tester.tap(editDetails);
      // Would have caught the pushNamed<bool> type-cast crash: the route is
      // built as Route<dynamic> unless the router types it.
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);

      // Seeded from the account, and the number is present but not editable.
      expect(find.text('Alexander Wright'), findsOneWidget);
      expect(find.text('+1 (555) 234-5678'), findsOneWidget);
      expect(
        find.text('Verified by OTP. Changing it needs a new verification.'),
        findsOneWidget,
      );
    });
  });
}
