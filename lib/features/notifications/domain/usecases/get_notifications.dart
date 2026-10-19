import '../entities/app_notification.dart';
import '../repositories/notification_repository.dart';

/// Everything the user should see right now, newest first.
class GetNotifications {
  const GetNotifications(this._repository);

  final NotificationRepository _repository;

  Future<List<AppNotification>> call() => _repository.fetch();
}
