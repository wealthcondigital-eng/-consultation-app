import '../../domain/entities/app_notification.dart';

/// Where notifications are read from and written to.
abstract interface class NotificationRemoteDataSource {
  Future<List<AppNotification>> fetch();

  Future<void> raise(List<AppNotification> notifications);

  Future<void> markRead(String id);

  Future<void> markAllRead();
}

/// Notifications held in memory, until the API serves them.
///
/// Kept for the life of the process rather than re-seeded per read, because the
/// entries that matter are the ones the app itself raises: book a slot and the
/// confirmation is in the list when you open it. Restarting the app loses them,
/// which is exactly the limitation the real endpoint removes.
class InMemoryNotificationRemoteDataSource
    implements NotificationRemoteDataSource {
  final List<AppNotification> _entries = [];

  @override
  Future<List<AppNotification>> fetch() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final now = DateTime.now();
    // Filtered here rather than in the UI: a reminder that has not come due is
    // not a notification yet, and every caller would otherwise have to know
    // that and remember to apply it.
    return _entries.where((entry) => entry.isVisibleAt(now)).toList()
      ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
  }

  /// Idempotent by id: an entry that is already here is left exactly as it is.
  ///
  /// It used to replace, which was fine while the only caller was a patient
  /// booking once. It is wrong now that the doctor's side raises these from a
  /// list it re-reads every time the screen opens — replacing would hand back
  /// an unread badge for an appointment they read about yesterday, on every
  /// single load.
  @override
  Future<void> raise(List<AppNotification> notifications) async {
    for (final notification in notifications) {
      final exists = _entries.any((entry) => entry.id == notification.id);
      if (exists) continue;

      _entries.add(notification);
    }
  }

  @override
  Future<void> markRead(String id) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index < 0) return;

    _entries[index] = _entries[index].copyWith(isRead: true);
  }

  @override
  Future<void> markAllRead() async {
    for (var index = 0; index < _entries.length; index++) {
      _entries[index] = _entries[index].copyWith(isRead: true);
    }
  }
}
