import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:consultation_app/features/notifications/domain/entities/app_notification.dart';
import 'package:consultation_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _devices = {
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 7 (412x915)': Size(412, 915),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _open(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const TeleconsultApp(initialRoute: AppRoutes.notifications),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    sl.reset();
    configureDependencies();

    final now = DateTime.now();
    await sl<NotificationRemoteDataSource>().raise([
      AppNotification(
        id: 'n1',
        kind: NotificationKind.bookingConfirmed,
        title: 'Appointment confirmed',
        body: 'Dr. Sunita Rao, tomorrow at 10:30 AM.',
        createdAt: now.subtract(const Duration(minutes: 5)),
        consultationId: 'c1',
      ),
      AppNotification(
        id: 'n2',
        kind: NotificationKind.consultationReminder,
        title: 'Starting in 15 minutes',
        body: 'Your video consultation begins soon.',
        createdAt: now.subtract(const Duration(days: 1)),
        isRead: true,
      ),
      AppNotification(
        id: 'n3',
        kind: NotificationKind.general,
        title: 'Welcome',
        body: 'Thanks for joining.',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ]);
  });

  for (final entry in _devices.entries) {
    testWidgets('lays out the timeline without overflow on ${entry.key}', (
      tester,
    ) async {
      await _open(tester, entry.value);

      expect(tester.takeException(), isNull);
      expect(find.text('Notifications'), findsOneWidget);
      // The pulse header carries the count.
      expect(find.textContaining('care feed'), findsOneWidget);
    });
  }

  testWidgets('only shows messages — no link to an appointment', (
    tester,
  ) async {
    await _open(tester, const Size(412, 915));

    expect(find.text('View appointment'), findsNothing);
  });

  testWidgets('tapping a new message marks it read and stays put', (
    tester,
  ) async {
    await _open(tester, const Size(412, 915));

    expect(find.text('NEW'), findsNWidgets(2));
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);

    // Has an appointment behind it, and still goes nowhere.
    await tester.tap(find.text('Appointment confirmed'));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('NEW'), findsNWidgets(1));
  });
}
