import '../entities/app_notification.dart';

/// Contract for the user's notification list.
abstract interface class NotificationRepository {
  /// Everything relevant as of now, newest first.
  Future<List<AppNotification>> fetch();

  /// Files new entries — a booking confirmation and the reminder that follows
  /// it. Written together because a booking produces both, and one without the
  /// other is a bug that only shows up fifteen minutes before a call.
  Future<void> raise(List<AppNotification> notifications);

  Future<void> markRead(String id);

  Future<void> markAllRead();
}
