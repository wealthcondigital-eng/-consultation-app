import '../../../../core/network/api_client.dart';
import '../../../onboarding/domain/repositories/role_repository.dart';
import '../../domain/entities/app_notification.dart';
import 'notification_remote_data_source.dart';

/// The user's notifications, from the consultation API.
///
/// **The contract**, served by `NotificationsController` in the NestJS API:
///
/// ```
/// GET /notifications?role=      -> { "notifications": [ … ] }
/// POST /notifications/{id}/read -> 204
/// POST /notifications/read?role= -> 204       // all of that side's
///
/// // One notification:
/// {
///   "id": "n_123",
///   "kind": "booking_confirmed",   // or consultation_reminder,
///                                  // consultation_starting, general
///   "title": "Consultation booked",
///   "body": "Dr Amit Verma, Mon, 18 Aug at 10:30 AM.",
///   "createdAt": "2026-09-12T09:00:00Z",
///   "showAfter": "2026-09-14T10:15:00Z",   // optional; omit for "now"
///   "read": false,
///   "consultationId": "c_456",             // optional
///   "startsAt": "2026-09-14T10:30:00Z"     // optional
/// }
/// ```
///
/// Two things the server owns rather than the app:
///
///  * **Writing the reminders.** They are filed when the booking is made — one
///    row per lead in `consultationReminderLeads`, each with `showAfter` set to
///    its own moment before the slot — not scheduled by a timer in the app,
///    which would need the app to be running to fire. The same rows are what
///    the push notifications are sent from, which is why the tray and this list
///    can never disagree about what was said.
///
///    Both sides' rows are written, which is the part only the server can do: a
///    patient books on their own phone, and the doctor is on a different device
///    that was not involved.
///  * **Deciding what is due.** `GET /notifications` returns what is relevant
///    now; the app does not ask for future rows and hide them, because a phone
///    whose clock is wrong would then show a reminder a day early.
///
/// There is no `POST /notifications` here on purpose: the app does not write
/// its own notifications once this is live. Booking a slot is what creates
/// them, and that happens server-side where the booking is stored.
class ApiNotificationRemoteDataSource implements NotificationRemoteDataSource {
  const ApiNotificationRemoteDataSource(this._client, this._roles);

  final ApiClient _client;

  /// The side the app is being used as. One account can be a patient and a
  /// doctor, and each side's bell shows only its own rows.
  final RoleRepository _roles;

  /// `?role=patient|doctor`, or nothing when no side is stored — the server
  /// then answers with both, as it did before the filter existed.
  Future<String> _roleQuery() async {
    try {
      final role = await _roles.readSelectedRole();
      return role == null ? '' : '?role=${role.key}';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<List<AppNotification>> fetch() async {
    final body = await _client.get('/notifications${await _roleQuery()}');
    final rows = body['notifications'];

    if (rows is! List) return const [];

    return rows.map(_from).nonNulls.toList()
      ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
  }

  @override
  Future<void> markRead(String id) => _client.post('/notifications/$id/read');

  @override
  Future<void> markAllRead() async =>
      _client.post('/notifications/read${await _roleQuery()}');

  /// Nothing to do: the server writes these when the booking is stored. Kept
  /// on the interface so the in-memory stand-in can behave as if it were a
  /// backend, and harmless here.
  @override
  Future<void> raise(List<AppNotification> notifications) async {}

  static AppNotification? _from(Object? row) {
    if (row is! Map) return null;

    final id = row['id'];
    final createdAt = DateTime.tryParse(row['createdAt'] as String? ?? '')?.toLocal();
    if (id is! String || createdAt == null) return null;

    return AppNotification(
      id: id,
      kind: _kindFrom(row['kind']),
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      createdAt: createdAt.toLocal(),
      showAfter: DateTime.tryParse(
        row['showAfter'] as String? ?? '',
      )?.toLocal(),
      isRead: row['read'] == true,
      consultationId: row['consultationId'] as String?,
      startsAt: DateTime.tryParse(row['startsAt'] as String? ?? '')?.toLocal(),
    );
  }

  /// An unknown kind reads as [NotificationKind.general] rather than being
  /// dropped: a message the app does not recognise is still a message, and
  /// hiding it would make a new server-side kind invisible until the app ships.
  static NotificationKind _kindFrom(Object? value) => switch (value) {
    'booking_confirmed' => NotificationKind.bookingConfirmed,
    'consultation_reminder' => NotificationKind.consultationReminder,
    'consultation_starting' => NotificationKind.consultationStarting,
    _ => NotificationKind.general,
  };
}
