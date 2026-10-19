import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/responsive/app_sizing.dart';
import 'package:consultation_app/core/update/app_update_controller.dart';
import 'package:consultation_app/core/update/app_update_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppUpdateController> _pumpCard(WidgetTester tester) async {
  final controller = sl<AppUpdateController>();
  await tester.pumpWidget(
    const MaterialApp(
      home: AppSizingScope(child: Scaffold(body: AppUpdateCard())),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  testWidgets('the profile card is absent with no update', (tester) async {
    await _pumpCard(tester);
    expect(find.text('A new version is ready'), findsNothing);
  });

  testWidgets('the card fills to 100% and says it is restarting', (
    tester,
  ) async {
    final controller = await _pumpCard(tester);

    controller.debugSet(AppUpdatePhase.available);
    await tester.pumpAndSettle();
    expect(find.text('A new version is ready'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);

    controller.debugSet(AppUpdatePhase.downloading, progress: 0.42);
    await tester.pumpAndSettle();
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('Update'), findsNothing);

    controller.debugSet(AppUpdatePhase.installing, progress: 1);
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Restarting the app…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a required update has no Later on the sheet', (tester) async {
    final controller = sl<AppUpdateController>()
      ..debugSet(AppUpdatePhase.available, required: true);

    await tester.pumpWidget(
      MaterialApp(
        // Above the navigator, as the app does, so the sheet's route sees it.
        builder: (context, child) => AppSizingScope(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => AppUpdateSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Important update'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(find.text('Update now'), findsOneWidget);
    expect(controller.isRequired, isTrue);
  });
}
