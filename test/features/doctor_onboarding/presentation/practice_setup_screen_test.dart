import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/core/widgets/app_button.dart';
import 'package:consultation_app/features/doctor_onboarding/data/datasources/doctor_onboarding_remote_data_source.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/practice_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screens the fee step must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _open(
  WidgetTester tester,
  Size size, {
  bool isWizardStep = true,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

  await tester.pumpWidget(
    TeleconsultApp(
      initialRoute: AppRoutes.doctorPracticeSetup,
      initialRouteArguments: isWizardStep ? true : null,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _saveButton() => find.byType(AppButton);

/// Brings the save into view before it is read.
///
/// The button is the last thing in a `ListView`, which builds lazily — so on a
/// phone it does not exist to be found until it has been scrolled to.
Future<AppButton> _save(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    _saveButton(),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();

  return tester.widget<AppButton>(_saveButton());
}

/// The amount field belonging to one of the two priced types.
///
/// Found by position: the video card is above the audio one, and both hold
/// exactly one `TextField`.
Finder _amountField(ConsultationFeeKind kind) =>
    find.byType(TextField).at(kind == ConsultationFeeKind.video ? 0 : 1);

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('PracticeSetupScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _open(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Video consultation'), findsOneWidget);
        expect(find.text('Audio consultation'), findsOneWidget);
      });
    }

    testWidgets('prices the two consultation types separately', (tester) async {
      await _open(tester, const Size(402, 874));

      // The stub holds ₹700 video and ₹400 audio. The screen used to collect
      // one amount and write it to both, so a voice call cost the same as a
      // video one — which is the whole reason there are two fields.
      expect(find.text('₹700 video · ₹400 audio'), findsOneWidget);

      await tester.enterText(_amountField(ConsultationFeeKind.audio), '250');
      await tester.pump();

      expect(find.text('₹700 video · ₹250 audio'), findsOneWidget);
    });

    testWidgets('accepts an amount the chips do not offer', (tester) async {
      await _open(tester, const Size(402, 874));

      // Four fixed chips and nothing else was the old screen, so ₹450 could
      // not be said at all.
      await tester.enterText(_amountField(ConsultationFeeKind.video), '450');
      await tester.pump();

      expect(find.text('₹450 video · ₹400 audio'), findsOneWidget);
      expect((await _save(tester)).onPressed, isNotNull);
    });

    testWidgets('Same as video copies the price across', (tester) async {
      await _open(tester, const Size(402, 874));

      await tester.tap(find.text('Same as video'));
      await tester.pump();

      // Collapsed to one label when the two agree, rather than repeating the
      // same number twice.
      expect(find.text('₹700'), findsWidgets);
      expect(find.text('Same as video'), findsNothing);
    });

    testWidgets('leaving one blank is allowed, and says what it means', (
      tester,
    ) async {
      await _open(tester, const Size(402, 874));

      await tester.enterText(_amountField(ConsultationFeeKind.audio), '');
      await tester.pump();

      expect(find.text('₹700 video'), findsOneWidget);
      expect(
        find.textContaining('not be offered audio consultations'),
        findsOneWidget,
      );
      // Still saveable: a doctor who only does video is a real doctor.
      expect((await _save(tester)).onPressed, isNotNull);
    });

    testWidgets('both blank cannot be saved', (tester) async {
      await _open(tester, const Size(402, 874));

      for (final kind in ConsultationFeeKind.values) {
        await tester.enterText(_amountField(kind), '');
        await tester.pump();
      }

      expect(find.text('—'), findsOneWidget);
      expect((await _save(tester)).onPressed, isNull);
    });

    testWidgets('a fee over the ceiling is refused with the right reason', (
      tester,
    ) async {
      await _open(tester, const Size(402, 874));

      await tester.enterText(_amountField(ConsultationFeeKind.video), '200000');
      await tester.pump();

      expect((await _save(tester)).onPressed, isNull);
    });

    testWidgets('a failed read still leaves a usable screen', (tester) async {
      // The bug this closes. The fee options came from the backend, so a read
      // that failed left no chips, no value, a permanently disabled Continue
      // and nothing said about why — the load's error was recorded and only
      // ever read by the save handler.
      sl.registerLazySingleton<DoctorOnboardingRemoteDataSource>(
        _FailingOnboardingSource.new,
      );

      await _open(tester, const Size(402, 874));

      expect(find.textContaining('No connection'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      // Seeded with the platform's suggestions, so a price can still be set.
      expect(find.text('₹500 video · ₹300 audio'), findsOneWidget);
      expect((await _save(tester)).onPressed, isNotNull);
    });

    testWidgets('opened from the profile it is not a wizard step', (
      tester,
    ) async {
      await _open(tester, const Size(402, 874), isWizardStep: false);

      expect(find.text('Consultation Fee'), findsOneWidget);
      expect(find.text('Setup Wizard'), findsNothing);
      expect(find.text('60% Completed'), findsNothing);

      // Below the fold, so scrolled to. Says 'Save fees' rather than
      // 'Continue': there is nothing after this when it is not a wizard step.
      expect((await _save(tester)).label, 'Save fees');
      // Skip belongs to the wizard: a doctor who came to change a price would
      // find it a second Back.
      expect(find.text('Skip for now'), findsNothing);
    });
  });
}

/// A backend that is not there.
class _FailingOnboardingSource extends FakeDoctorOnboardingRemoteDataSource {
  @override
  Future<PracticeSetup> fetchPracticeSetup() async =>
      throw const Failure.network();
}
