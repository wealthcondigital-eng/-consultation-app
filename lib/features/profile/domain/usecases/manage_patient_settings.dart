import '../entities/notification_settings.dart';
import '../repositories/profile_repository.dart';

/// The patient's notification preferences: read them, and flip one.
class ManagePatientSettings {
  const ManagePatientSettings(this._repository);

  final ProfileRepository _repository;

  Future<NotificationSettings> load() => _repository.fetchSettings();

  /// One switch at a time, which is also how the screen works. The alternative
  /// — sending the whole object — would let a screen that has been open since
  /// this morning quietly undo a change made on another device this afternoon.
  Future<NotificationSettings> set(
    PatientNotificationToggle toggle,
    bool value,
  ) {
    return _repository.setNotificationPreference(toggle, value);
  }
}
