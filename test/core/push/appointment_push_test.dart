import 'package:consultation_app/core/push/appointment_push.dart';
import 'package:consultation_app/core/push/incoming_call_push.dart';
import 'package:consultation_app/features/notifications/domain/entities/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

/// One appointment message as the server sends it. Every value is a string,
/// because FCM data payloads have no types — which is the thing this parsing
/// exists to deal with.
Map<String, dynamic> _message({
  String type = 'appointment',
  String kind = 'consultation_reminder',
  String title = 'Consultation in 15 minutes',
  String body = 'Dr Amit Verma · Find somewhere quiet.',
  String consultationId = 'c_1',
  String startsAt = '2026-09-22T03:30:00.000Z',
  String notificationId = 'n_1',
}) => {
  'type': type,
  'kind': kind,
  'title': title,
  'body': body,
  'consultationId': consultationId,
  'startsAt': startsAt,
  'notificationId': notificationId,
};

void main() {
  group('AppointmentPush', () {
    test('reads a reminder off a data payload', () {
      final push = AppointmentPush.tryParse(_message());

      expect(push, isNotNull);
      expect(push!.kind, NotificationKind.consultationReminder);
      expect(push.title, 'Consultation in 15 minutes');
      expect(push.consultationId, 'c_1');
      expect(push.notificationId, 'n_1');
      expect(push.startsAt, DateTime.parse('2026-09-22T03:30:00Z').toLocal());
      expect(push.isStarting, isFalse);
    });

    test('the two-minute one is a different kind, and says so', () {
      final push = AppointmentPush.tryParse(
        _message(kind: 'consultation_starting'),
      );

      expect(push!.isStarting, isTrue);
    });

    test('ignores an incoming call, which rings rather than reminds', () {
      final call = {
        'type': 'incoming_call',
        'consultationId': 'c_1',
        'channelId': 'consult-abc',
        'mode': 'video',
        'callerName': 'Riya',
        'ringSeconds': '30',
      };

      expect(AppointmentPush.tryParse(call), isNull);
      // And the reverse, so one message can never be drawn twice.
      expect(IncomingCallPush.tryParse(_message()), isNull);
    });

    test('an unknown kind still arrives, as general', () {
      final push = AppointmentPush.tryParse(
        _message(kind: 'doctor_ran_late_sorry'),
      );

      // Dropping it would make a new server-side kind invisible until the app
      // ships, which is the slowest possible way to find out about one.
      expect(push, isNotNull);
      expect(push!.kind, NotificationKind.general);
    });

    test('survives a missing startsAt and a blank notification id', () {
      final push = AppointmentPush.tryParse(
        _message(startsAt: '', notificationId: ''),
      );

      // A reminder with no countdown is still a reminder worth showing, unlike
      // a call with no channel — which is why this is nullable and not fatal.
      expect(push, isNotNull);
      expect(push!.startsAt, isNull);
      expect(push.notificationId, isNull);
    });

    test('a message with nothing to say is not shown', () {
      expect(
        AppointmentPush.tryParse(_message(title: '', body: '')),
        isNull,
        reason: 'an empty tray line is worse than no notification',
      );
    });
  });
}
