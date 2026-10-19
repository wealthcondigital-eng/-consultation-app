import 'package:consultation_app/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:consultation_app/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:consultation_app/features/notifications/domain/entities/app_notification.dart';
import 'package:consultation_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:consultation_app/features/notifications/domain/usecases/announce_booking.dart';
import 'package:consultation_app/features/notifications/domain/usecases/get_notifications.dart';
import 'package:consultation_app/features/notifications/domain/usecases/mark_notifications_read.dart';
import 'package:consultation_app/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:consultation_app/features/onboarding/domain/entities/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

NotificationRepository _repository() =>
    NotificationRepositoryImpl(InMemoryNotificationRemoteDataSource());

void main() {
  group('AppNotification', () {
    test('a reminder is not a notification until it comes due', () {
      // Written on Monday for a Thursday appointment. It must not sit in the
      // list for three days saying the consultation starts in 15 minutes.
      final reminder = AppNotification(
        id: 'r1',
        kind: NotificationKind.consultationReminder,
        title: 'Starts soon',
        body: '',
        createdAt: DateTime(2026, 9, 14, 9),
        showAfter: DateTime(2026, 9, 17, 10, 15),
      );

      expect(reminder.isVisibleAt(DateTime(2026, 9, 14, 9, 30)), isFalse);
      expect(reminder.isVisibleAt(DateTime(2026, 9, 17, 10, 14)), isFalse);
      expect(reminder.isVisibleAt(DateTime(2026, 9, 17, 10, 15)), isTrue);
      expect(reminder.isVisibleAt(DateTime(2026, 9, 17, 10, 31)), isTrue);
    });
  });

  group('AnnounceBooking', () {
    test('books a confirmation now and a reminder before the call', () async {
      final repository = _repository();
      final startsAt = DateTime.now().add(const Duration(days: 2));

      await AnnounceBooking(repository)(
        consultationId: 'c1',
        counterpartName: 'Dr Amit Verma',
        startsAt: startsAt,
        scheduledFor: 'Mon, 14 Sep at 10:30 AM',
      );

      final visible = await repository.fetch();

      // Only the confirmation is due. The reminder exists, and surfaces on the
      // day — writing it now is what makes it survive the app being closed
      // until then, with nothing running to fire a timer.
      expect(visible, hasLength(1));
      expect(visible.single.kind, NotificationKind.bookingConfirmed);
      expect(visible.single.body, contains('Dr Amit Verma'));
      expect(visible.single.body, contains('Mon, 14 Sep at 10:30 AM'));
    });

    test('the reminder lands fifteen minutes before, and says what to '
        'bring', () async {
      final repository = _repository();
      // A consultation that starts in ten minutes: the reminder is already due.
      final startsAt = DateTime.now().add(const Duration(minutes: 10));

      await AnnounceBooking(repository)(
        consultationId: 'c2',
        counterpartName: 'Dr Neha Gupta',
        startsAt: startsAt,
        scheduledFor: 'Today at 4:00 PM',
      );

      final visible = await repository.fetch();
      final reminder = visible.firstWhere(
        (entry) => entry.kind == NotificationKind.consultationReminder,
      );

      expect(reminder.showAfter, startsAt.subtract(consultationReminderLead));
      // "Starts soon" on its own is a reminder people read and put down.
      expect(reminder.body, contains('reports'));
      expect(reminder.startsAt, startsAt);
    });

    test('booking the same consultation twice does not duplicate it', () async {
      final repository = _repository();
      final announce = AnnounceBooking(repository);
      final startsAt = DateTime.now().add(const Duration(minutes: 5));

      await announce(
        consultationId: 'c3',
        counterpartName: 'Dr Amit Verma',
        startsAt: startsAt,
        scheduledFor: 'Today at 4:00 PM',
      );
      await announce(
        consultationId: 'c3',
        counterpartName: 'Dr Amit Verma',
        startsAt: startsAt,
        scheduledFor: 'Today at 4:00 PM',
      );

      // Announcing twice writes the same set once — not that the set is two.
      final once = await repository.fetch();
      expect(once.map((entry) => entry.id).toSet(), hasLength(once.length));
    });

    test('reminds at thirty, fifteen, five and two minutes', () async {
      // Four rather than one, because they do different jobs: finish up, get
      // ready, stop and go, the room is open. All written at booking time, so
      // they arrive with nothing running to fire a timer.
      //
      // Starting in a minute, so every lead is already behind us and all four
      // are due — otherwise `fetch` would hide the ones this is checking.
      final repository = _repository();
      final startsAt = DateTime.now().add(const Duration(minutes: 1));

      await AnnounceBooking(repository)(
        consultationId: 'c10',
        counterpartName: 'Dr Amit Verma',
        startsAt: startsAt,
        scheduledFor: 'Today at 8:30 PM',
      );

      final reminders = (await repository.fetch())
          .where((entry) => entry.kind == NotificationKind.consultationReminder)
          .toList();

      expect(reminders, hasLength(consultationReminderLeads.length));

      // Each keyed by its own lead. Sharing one id would leave only the first
      // of the four ever written, which is exactly what the old id did.
      expect(
        reminders.map((entry) => entry.id).toSet(),
        hasLength(consultationReminderLeads.length),
      );

      // And each lands at its own moment.
      for (final lead in consultationReminderLeads) {
        expect(
          reminders.any((entry) => entry.showAfter == startsAt.subtract(lead)),
          isTrue,
          reason: 'no reminder ${lead.inMinutes} minutes before',
        );
      }

      // The distance is the message: the last one says the room is open, not
      // "starts soon" for the fourth time.
      final last = reminders.firstWhere(
        (entry) =>
            entry.showAfter == startsAt.subtract(const Duration(minutes: 2)),
      );
      expect(last.body, contains('join now'));
    });

    test('re-announcing does not resurrect a read badge', () async {
      // The doctor's side raises these from a list it re-reads on every load.
      // Replacing the entry would hand back an unread badge for an appointment
      // they read about yesterday, every single time they opened the screen.
      final repository = _repository();
      final announce = AnnounceBooking(repository);
      final startsAt = DateTime.now().add(const Duration(minutes: 5));

      await announce(
        consultationId: 'c8',
        counterpartName: 'Dr Amit Verma',
        startsAt: startsAt,
        scheduledFor: 'Today at 4:00 PM',
      );
      await repository.markAllRead();

      await announce(
        consultationId: 'c8',
        counterpartName: 'Dr Amit Verma',
        startsAt: startsAt,
        scheduledFor: 'Today at 4:00 PM',
      );

      final entries = await repository.fetch();
      expect(entries.every((entry) => entry.isRead), isTrue);
    });

    test(
      'the doctor is told somebody booked them, not that they booked',
      () async {
        // The same appointment is "you booked this" to a patient and "somebody
        // booked you" to a doctor — and a doctor told to have their prescriptions
        // ready is being handed the patient's instructions.
        final repository = _repository();

        await AnnounceBooking(repository)(
          consultationId: 'c9',
          counterpartName: 'Rahul Sharma',
          startsAt: DateTime.now().add(const Duration(minutes: 10)),
          scheduledFor: 'Today at 4:00 PM',
          forRole: UserRole.doctor,
        );

        final entries = await repository.fetch();
        final booked = entries.firstWhere(
          (entry) => entry.kind == NotificationKind.bookingConfirmed,
        );
        final reminder = entries.firstWhere(
          (entry) => entry.kind == NotificationKind.consultationReminder,
        );

        expect(booked.title, 'New appointment booked');
        expect(booked.body, contains('Rahul Sharma booked you'));
        expect(reminder.body, isNot(contains('Keep any reports')));
      },
    );

    test('a failure to file the notification never fails the booking', () async {
      // The appointment exists either way, and it is on the appointments list.
      await expectLater(
        AnnounceBooking(_ThrowingRepository())(
          consultationId: 'c4',
          counterpartName: 'Dr Amit Verma',
          startsAt: DateTime.now(),
          scheduledFor: 'Today',
        ),
        completes,
      );
    });
  });

  group('NotificationsController', () {
    Future<NotificationsController> controllerWith(
      NotificationRepository repository,
    ) async {
      final controller = NotificationsController(
        GetNotifications(repository),
        MarkNotificationsRead(repository),
      );
      await controller.load();
      return controller;
    }

    test('an empty list is empty only once it has been read', () async {
      final controller = NotificationsController(
        GetNotifications(_repository()),
        MarkNotificationsRead(_repository()),
      );

      // Before the first read there is nothing to say, and an empty state shown
      // over a list that is still loading reads as "you have nothing".
      expect(controller.isEmpty, isFalse);

      await controller.load();
      expect(controller.isEmpty, isTrue);
    });

    test('counts what is unread', () async {
      final repository = _repository();
      await AnnounceBooking(repository)(
        consultationId: 'c5',
        counterpartName: 'Dr Amit Verma',
        startsAt: DateTime.now().add(const Duration(minutes: 5)),
        scheduledFor: 'Today at 4:00 PM',
      );

      final controller = await controllerWith(repository);

      // The confirmation plus every reminder already due — five minutes out,
      // that is the 30, 15 and 5 minute ones. Counted from the list rather
      // than hard-coded, so adding a lead does not break this.
      expect(controller.unreadCount, controller.notifications.length);
      expect(controller.unreadCount, greaterThan(1));
      expect(controller.hasUnread, isTrue);
    });

    test('opening one marks it read straight away', () async {
      final repository = _repository();
      await AnnounceBooking(repository)(
        consultationId: 'c6',
        counterpartName: 'Dr Amit Verma',
        startsAt: DateTime.now().add(const Duration(minutes: 5)),
        scheduledFor: 'Today at 4:00 PM',
      );

      final controller = await controllerWith(repository);
      final total = controller.notifications.length;
      final first = controller.notifications.first;

      await controller.open(first);

      // Locally first: the tap opens a screen, and the row must not still be
      // bold when the user comes back because a write was in flight.
      expect(controller.unreadCount, total - 1);
      expect(
        controller.notifications.firstWhere((n) => n.id == first.id).isRead,
        isTrue,
      );

      // And it stuck, rather than only looking read until the next load.
      await controller.load();
      expect(controller.unreadCount, total - 1);
    });

    test('marking all read clears the badge', () async {
      final repository = _repository();
      await AnnounceBooking(repository)(
        consultationId: 'c7',
        counterpartName: 'Dr Amit Verma',
        startsAt: DateTime.now().add(const Duration(minutes: 5)),
        scheduledFor: 'Today at 4:00 PM',
      );

      final controller = await controllerWith(repository);
      await controller.markAllRead();

      expect(controller.hasUnread, isFalse);

      await controller.load();
      expect(controller.hasUnread, isFalse);
    });
  });
}

class _ThrowingRepository implements NotificationRepository {
  @override
  Future<List<AppNotification>> fetch() async => throw StateError('offline');
  @override
  Future<void> raise(List<AppNotification> notifications) async =>
      throw StateError('offline');
  @override
  Future<void> markRead(String id) async => throw StateError('offline');
  @override
  Future<void> markAllRead() async => throw StateError('offline');
}
