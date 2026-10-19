import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor_settings.dart';
import '../../domain/usecases/manage_doctor_practice.dart';

/// Presentation state for the doctor's notification settings.
///
/// Optimistic, like the presence dial: the switch answers the tap and reverts
/// if the backend refuses. A switch that waits on a round trip before moving
/// reads as broken, and the doctor taps it again.
class DoctorSettingsController extends ChangeNotifier {
  DoctorSettingsController(this._manage);

  final ManageDoctorSettings _manage;

  DoctorSettings _settings = const DoctorSettings();
  DoctorSettings get settings => _settings;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;

  /// True once the preferences have been read at least once.
  ///
  /// What lets the screen tell a failed *read* — nothing to show, so an error
  /// page — from a failed *write*, where the rows are still perfectly readable
  /// and the message belongs in a snackbar.
  bool get hasLoaded => _hasLoaded;

  bool get isInitialLoad => _isLoading && !_hasLoaded;

  /// Which switch is in flight, so only that row shows as busy.
  DoctorNotificationToggle? _pending;
  DoctorNotificationToggle? get pending => _pending;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _settings = await _manage.load();
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

  Future<void> toggle(DoctorNotificationToggle toggle) async {
    if (_pending != null || !_hasLoaded) return;

    final previous = _settings;
    final value = !toggle.from(_settings);

    _pending = toggle;
    _errorMessage = null;
    _settings = toggle.applyTo(_settings, value);
    notifyListeners();

    try {
      // The answer rather than the guess: the server may normalise something,
      // and the screen should show what is stored.
      _settings = await _manage.set(toggle, value);
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      _settings = previous;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      _settings = previous;
    } finally {
      _pending = null;
      notifyListeners();
    }
  }

  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
