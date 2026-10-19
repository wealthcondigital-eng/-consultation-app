import '../../../../core/error/failure.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_data_source.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._remote);

  final NotificationRemoteDataSource _remote;

  @override
  Future<List<AppNotification>> fetch() async {
    try {
      return await _remote.fetch();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }

  @override
  Future<void> raise(List<AppNotification> notifications) =>
      _remote.raise(notifications);

  @override
  Future<void> markRead(String id) => _remote.markRead(id);

  @override
  Future<void> markAllRead() => _remote.markAllRead();
}
