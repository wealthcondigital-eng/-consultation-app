import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor_application.dart';
import '../../domain/usecases/watch_application_status.dart';

/// Presentation state for the "under review" screen.
///
/// The verification happens on the board's side, so the screen only watches.
class ApplicationStatusController extends ChangeNotifier {
  ApplicationStatusController(this._watchApplicationStatus);

  final WatchApplicationStatus _watchApplicationStatus;

  StreamSubscription<DoctorApplication>? _subscription;

  DoctorApplication? _application;
  DoctorApplication? get application => _application;

  bool get isApproved => _application?.isApproved ?? false;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void watch(DoctorApplication application) {
    if (_subscription != null) return;

    _application = application;
    notifyListeners();

    _subscription = _watchApplicationStatus(application.id).listen(
      (update) {
        _application = update;
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage = error is Failure
            ? error.message
            : const Failure.unexpected().message;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
