import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/home_feed.dart';
import '../../domain/entities/patient_dashboard.dart';
import '../../domain/usecases/get_home_feed.dart';
import '../../domain/usecases/get_patient_dashboard.dart';

/// Presentation state for the patient home screen.
///
/// Two reads, and they are deliberately separate. [feed] is the catalogue —
/// the specialities and the doctor list — which is the same for everybody;
/// [dashboard] is this patient's own numbers, live consultation and history,
/// which is nobody else's. They are fetched together and fail independently:
/// a dashboard that could not load must not take the doctor list down with it,
/// because Consult Now still works.
class PatientHomeController extends ChangeNotifier {
  PatientHomeController(this._getHomeFeed, this._getDashboard);

  final GetHomeFeed _getHomeFeed;
  final GetPatientDashboard _getDashboard;

  HomeFeed _feed = const HomeFeed.empty();
  HomeFeed get feed => _feed;

  PatientDashboard _dashboard = const PatientDashboard.empty();
  PatientDashboard get dashboard => _dashboard;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;

  /// True on the very first load, when there is nothing to show yet.
  bool get isInitialLoad => _isLoading && !_hasLoaded;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Both at once: the greeting should not wait on the doctor list, nor the
    // other way round.
    final feed = _getHomeFeed();
    final dashboard = _dashboardOrNull();

    try {
      _feed = await feed;
      _hasLoaded = true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    }

    // Kept if it failed. A patient who has just come back online should see
    // last read's numbers rather than have them blank out.
    _dashboard = await dashboard ?? _dashboard;

    // Applied after both, because the name is the dashboard's and the feed is
    // what renders the greeting.
    _feed = _feed.withPatientFirstName(_dashboard.firstName);

    _isLoading = false;
    notifyListeners();
  }

  /// Never throws: a patient who has not finished onboarding, or a read that
  /// fails, gets the generic greeting and no figures rather than an error where
  /// their dashboard should be.
  Future<PatientDashboard?> _dashboardOrNull() async {
    try {
      return await _getDashboard();
    } catch (_) {
      return null;
    }
  }
}
