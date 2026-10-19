import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/usecases/get_notifications.dart';
import '../../domain/usecases/mark_notifications_read.dart';

/// Presentation state for the notifications page, and for the unread dot on
/// whatever opens it.
class NotificationsController extends ChangeNotifier {
  NotificationsController(this._getNotifications, this._markRead);

  final GetNotifications _getNotifications;
  final MarkNotificationsRead _markRead;

  List<AppNotification> _notifications = const [];
  List<AppNotification> get notifications => _notifications;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  bool get hasUnread => unreadCount > 0;

  bool get isEmpty => _hasLoaded && _notifications.isEmpty;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notifications = await _getNotifications();
      _hasLoaded = true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marks one row read, locally first.
  ///
  /// The list is updated before the call rather than after it: tapping a
  /// notification opens something, and the row must not still be bold when the
  /// user comes back because a write was still in flight.
  Future<void> open(AppNotification notification) async {
    if (notification.isRead) return;

    _replace(notification.copyWith(isRead: true));
    notifyListeners();

    try {
      await _markRead.one(notification.id);
    } catch (_) {
      // The badge is not worth an error message. The next load corrects it.
    }
  }

  Future<void> markAllRead() async {
    if (!hasUnread) return;

    _notifications = [
      for (final notification in _notifications)
        notification.copyWith(isRead: true),
    ];
    notifyListeners();

    try {
      await _markRead.all();
    } catch (_) {
      // As above.
    }
  }

  void _replace(AppNotification updated) {
    _notifications = [
      for (final notification in _notifications)
        if (notification.id == updated.id) updated else notification,
    ];
  }
}
