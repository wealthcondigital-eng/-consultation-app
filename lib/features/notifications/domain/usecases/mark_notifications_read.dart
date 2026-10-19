import '../repositories/notification_repository.dart';

/// Clears the unread badge — one row, or the lot.
class MarkNotificationsRead {
  const MarkNotificationsRead(this._repository);

  final NotificationRepository _repository;

  Future<void> one(String id) => _repository.markRead(id);

  Future<void> all() => _repository.markAllRead();
}
