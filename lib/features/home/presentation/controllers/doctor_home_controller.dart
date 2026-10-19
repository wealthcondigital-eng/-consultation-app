import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor_dashboard.dart';
import '../../domain/usecases/manage_doctor_dashboard.dart';

/// Presentation state for the doctor's home screen.
class DoctorHomeController extends ChangeNotifier {
  DoctorHomeController(this._manageDashboard);

  final ManageDoctorDashboard _manageDashboard;

  DoctorDashboard _dashboard = const DoctorDashboard.empty();
  DoctorDashboard get dashboard => _dashboard;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;
  bool get isInitialLoad => _isLoading && !_hasLoaded;

  /// True while the presence change is in flight — the dial shows this.
  bool _isSwitchingPresence = false;
  bool get isSwitchingPresence => _isSwitchingPresence;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _dashboard = await _manageDashboard.load();
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

  /// Flips the doctor's presence.
  ///
  /// Optimistic: the dial answers the tap immediately and reverts if the
  /// backend refuses, because a switch that lags reads as broken.
  Future<void> togglePresence() async {
    if (_isSwitchingPresence || !_hasLoaded) return;

    final previous = _dashboard.isOnline;
    _isSwitchingPresence = true;
    _errorMessage = null;
    _dashboard = _dashboard.copyWith(isOnline: !previous);
    notifyListeners();

    try {
      await _manageDashboard.setOnline(!previous);
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      _dashboard = _dashboard.copyWith(isOnline: previous);
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      _dashboard = _dashboard.copyWith(isOnline: previous);
    } finally {
      _isSwitchingPresence = false;
      notifyListeners();
    }
  }

  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
