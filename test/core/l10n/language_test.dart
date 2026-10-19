import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/l10n/hi/hi.dart';
import 'package:consultation_app/core/l10n/language_controller.dart';
import 'package:consultation_app/core/l10n/tr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    configureDependencies();
  });

  // The string table is static: a test that leaves Hindi on would run every
  // test after it in Hindi.
  tearDown(() => AppStrings.use(AppLanguage.english));

  group('tr', () {
    test('English is the source and passes through', () {
      expect(tr('Language'), 'Language');
      expect(tr('Some text nobody translated'), 'Some text nobody translated');
    });

    test('fills placeholders', () {
      expect(tr('Updating · {percent}%', {'percent': 42}), 'Updating · 42%');
    });

    test('Hindi uses the table and falls back to English', () {
      AppStrings.use(AppLanguage.hindi);
      expect(tr('Language'), hindiStrings['Language'] ?? 'Language');
      expect(tr('Some text nobody translated'), 'Some text nobody translated');
    });

    test('every Hindi entry keeps its placeholders', () {
      final placeholder = RegExp(r'\{[a-zA-Z_]+\}');
      for (final entry in hindiStrings.entries) {
        final english = placeholder
            .allMatches(entry.key)
            .map((m) => m[0])
            .toSet();
        final hindi = placeholder
            .allMatches(entry.value)
            .map((m) => m[0])
            .toSet();
        expect(hindi, english, reason: 'placeholders in "${entry.key}"');
      }
    });
  });

  testWidgets('the profile switches the app to Hindi and back', (tester) async {
    tester.view
      ..physicalSize = const Size(402, 874)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const TeleconsultApp(initialRoute: AppRoutes.patientProfile),
    );
    await tester.pumpAndSettle();

    final row = find.text('Language');
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(sl<LanguageController>().language, AppLanguage.hindi);
    expect(tester.takeException(), isNull);

    await sl<LanguageController>().setLanguage(AppLanguage.english);
    await tester.pumpAndSettle();
    expect(AppStrings.language, AppLanguage.english);
  });

  test('the choice is remembered', () async {
    await LanguageController().setLanguage(AppLanguage.hindi);
    final second = LanguageController();
    await second.restore();
    expect(second.language, AppLanguage.hindi);
    AppStrings.use(AppLanguage.english);
  });
}
