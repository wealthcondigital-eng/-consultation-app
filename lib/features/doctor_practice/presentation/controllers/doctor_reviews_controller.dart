import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor_review.dart';
import '../../domain/usecases/manage_doctor_practice.dart';

/// Presentation state for the doctor's own reviews.
class DoctorReviewsController extends ChangeNotifier {
  DoctorReviewsController(this._getReviews);

  final GetDoctorReviews _getReviews;

  List<DoctorReview> _reviews = const [];
  List<DoctorReview> get reviews => _reviews;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;
  bool get isInitialLoad => _isLoading && !_hasLoaded;

  /// Loaded, and there is nothing — distinct from still loading, so the screen
  /// shows an empty state rather than a spinner that never resolves.
  bool get isEmpty => _hasLoaded && _reviews.isEmpty;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// The running average of what is on this page.
  ///
  /// Not the doctor's profile rating, which counts every rating including the
  /// ones with nothing written on them. The two differ, and the label says
  /// which this is rather than quietly contradicting the dashboard.
  double get average {
    if (_reviews.isEmpty) return 0;

    final total = _reviews.fold<int>(0, (sum, review) => sum + review.rating);
    return total / _reviews.length;
  }

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reviews = await _getReviews();
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
}
