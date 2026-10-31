import '../../features/notifications/domain/entities/app_notification.dart';

/// An appointment message, as it arrives in a push.
///
/// The booking confirmation and the four reminders before it starts are all
/// this shape — only the copy and the timing differ — so one type reads them
/// all and the app draws them the same way.
///
/// Deliberately not [IncomingCallPush]. A call is an interruption that has to
/// ring over the lock screen and cannot be swiped away; an appointment is a
/// line in the tray that the person deals with when they look. Sharing a type
/// would mean sharing a channel, and a reminder that rings like a call is one
/// people turn off — along with the calls.
class AppointmentPush {
  const AppointmentPush({
    required this.consultationId,
    required this.kind,
    required this.title,
    required this.body,
    this.startsAt,
    this.notificationId,
  });

  final String consultationId;
  final NotificationKind kind;

  final String title;
  final String body;

  /// When the consultation starts. Null when the server did not say, which is
  /// only the case for a general announcement.
  final DateTime? startsAt;

  /// The server-side row this was sent from, so a tap can mark it read rather
  /// than leaving an unread badge for something already seen.
  final String? notificationId;

  /// Whether this is the one that says the room is open.
  bool get isStarting => kind == NotificationKind.consultationStarting;

  /// Reads one out of an FCM data payload, or null when it is not an
  /// appointment message.
  ///
  /// Every value arrives as a string — FCM data payloads have no types — so
  /// each one is parsed rather than cast. Unlike a call, a missing field is
  /// survivable here: a reminder with no `startsAt` is still a reminder worth
  /// showing, where a call with no channel is nothing anyone could answer.
  static AppointmentPush? tryParse(Map<String, dynamic> data) {
    if (data['type'] != 'appointment') return null;

    final title = (data['title'] as String?)?.trim() ?? '';
    final body = (data['body'] as String?)?.trim() ?? '';
    if (title.isEmpty && body.isEmpty) return null;

    final startsAt = DateTime.tryParse(data['startsAt'] as String? ?? '')?.toLocal();
    final notificationId = (data['notificationId'] as String?)?.trim();

    return AppointmentPush(
      consultationId: (data['consultationId'] as String?)?.trim() ?? '',
      kind: _kindFrom(data['kind']),
      title: title,
      body: body,
      startsAt: startsAt?.toLocal(),
      notificationId: notificationId == null || notificationId.isEmpty
          ? null
          : notificationId,
    );
  }

  /// An unknown kind reads as [NotificationKind.general] rather than being
  /// dropped — the same rule the notifications list follows. A message the app
  /// does not recognise is still a message, and hiding it would make a new
  /// server-side kind invisible until the app ships.
  static NotificationKind _kindFrom(Object? value) => switch (value) {
    'booking_confirmed' => NotificationKind.bookingConfirmed,
    'consultation_reminder' => NotificationKind.consultationReminder,
    'consultation_starting' => NotificationKind.consultationStarting,
    _ => NotificationKind.general,
  };
}
