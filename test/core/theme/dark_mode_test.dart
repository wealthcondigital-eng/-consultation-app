import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/theme/app_colors.dart';
import 'package:consultation_app/core/theme/theme_controller.dart';
import 'package:consultation_app/features/onboarding/domain/entities/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The page background the patient sees, read off the widget tree.
Color? _pageBackground(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor;

Future<void> _open(WidgetTester tester, String route, {Object? args}) async {
  tester.view
    ..physicalSize = const Size(402, 874)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TeleconsultApp(initialRoute: route, initialRouteArguments: args),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    configureDependencies();
  });

  // The palette is static, so a test that leaves it dark would paint every
  // test after it dark too.
  tearDown(() => AppColors.use(AppPalette.light));

  testWidgets('switching to dark repaints the open screen in place', (
    tester,
  ) async {
    await _open(tester, AppRoutes.home, args: UserRole.patient);
    expect(_pageBackground(tester), AppPalette.light.canvas);

    await sl<ThemeController>().setMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(AppColors.isDark, isTrue);
    expect(_pageBackground(tester), AppPalette.dark.canvas);
    expect(tester.takeException(), isNull);

    // And back, with the screen still where it was.
    await sl<ThemeController>().setMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(_pageBackground(tester), AppPalette.light.canvas);
  });

  testWidgets('the profile offers the choice and applies it', (tester) async {
    await _open(tester, AppRoutes.patientProfile);

    final row = find.text('Appearance');
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('System default'), findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(sl<ThemeController>().mode, ThemeMode.dark);
    expect(AppColors.isDark, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('the choice is remembered', () async {
    final first = ThemeController();
    await first.setMode(ThemeMode.dark);

    final second = ThemeController();
    await second.restore();
    expect(second.mode, ThemeMode.dark);
  });

  testWidgets('the appearance sheet repaints itself when the theme changes', (
    tester,
  ) async {
    await sl<ThemeController>().setMode(ThemeMode.dark);
    await _open(tester, AppRoutes.patientProfile);

    final row = find.text('Appearance');
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    // The sheet's own painted surface, the container around its options.
    Color? sheetColor() {
      final sheet = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('System default').last,
              matching: find.byType(AnimatedContainer),
            )
            .last,
      );
      return (sheet.decoration as BoxDecoration?)?.color;
    }

    expect(sheetColor(), AppPalette.dark.surface);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(sheetColor(), AppPalette.light.surface);
    expect(tester.takeException(), isNull);
  });
}
