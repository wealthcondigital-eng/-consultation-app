/// What a notification is telling the user, and what tapping it should do.
enum NotificationKind {
  /// A slot was booked and paid for.
  bookingConfirmed,

  /// The consultation starts shortly — the one that asks them to have their
  /// reports to hand.
  consultationReminder,

  /// The consultation is starting now and the room is open.
  consultationStarting,

  /// Anything the platform has to say that is not about one consultation.
  general,
}

/// One entry in the notifications page.
///
/// Carries the moment it becomes *relevant* as well as the moment it was
/// created, because the two differ for the case this exists for: the reminder
/// for a Thursday appointment is written on Monday when the booking is made,
/// and must not appear in the list until Thursday. Writing it up front is what
/// lets the reminder survive the app being closed for three days — nothing has
/// to be running for it to arrive.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.showAfter,
    this.isRead = false,
    this.consultationId,
    this.startsAt,
  });

  final String id;
  final NotificationKind kind;

  /// One line. The tray shows this alone when it has no room for the body.
  final String title;

  final String body;

  final DateTime createdAt;

  /// When it should first be shown. Null means immediately.
  final DateTime? showAfter;

  final bool isRead;

  /// The consultation this is about, for the row to open.
  final String? consultationId;

  /// When that consultation starts, for the row to count down to.
  final DateTime? startsAt;

  /// Whether this belongs in the list as of [now].
  bool isVisibleAt(DateTime now) =>
      showAfter == null || !showAfter!.isAfter(now);

  /// Sorts the list: newest relevant thing first.
  DateTime get sortKey => showAfter ?? createdAt;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    showAfter: showAfter,
    isRead: isRead ?? this.isRead,
    consultationId: consultationId,
    startsAt: startsAt,
  );
}

/// When the reminders for a consultation land, furthest out first.
///
/// Four of them rather than one, because they are doing different jobs. Half an
/// hour out is "finish what you are doing"; fifteen minutes is "find your
/// reports and somewhere quiet"; five is "stop and go"; two is "the room is
/// open". A single reminder has to pick one of those and gets the other three
/// wrong — too early to act on, or too late to prepare for.
///
/// Ordered longest-first so the copy for each can be picked by position, and so
/// the list reads the way the day does.
const List<Duration> consultationReminderLeads = [
  Duration(minutes: 30),
  Duration(minutes: 15),
  Duration(minutes: 5),
  Duration(minutes: 2),
];

/// The lead the join window is keyed to — and the one the server uses to decide
/// whether an appointment may be opened yet. See `Appointment.joinLead`.
const Duration consultationReminderLead = Duration(minutes: 15);
