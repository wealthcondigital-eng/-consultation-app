import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/doctor_list_filter.dart';
import '../../domain/usecases/get_doctors.dart';

/// Presentation state for the doctor listing.
///
/// Search and filtering run over the loaded list rather than round-tripping to
/// the backend, so typing stays instant.
class DoctorListController extends ChangeNotifier {
  DoctorListController(this._getDoctors);

  final GetDoctors _getDoctors;

  List<Doctor> _allDoctors = const [];

  String _query = '';
  String get query => _query;

  DoctorListFilter _filter = DoctorListFilter.all;
  DoctorListFilter get filter => _filter;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isInitialLoad => _isLoading && _allDoctors.isEmpty;

  /// The doctors actually shown, after the search box and the chip row.
  List<Doctor> get visibleDoctors {
    final matching = _allDoctors
        .where((doctor) => doctor.matches(_query))
        .toList();
    return _filter.apply(matching);
  }

  /// True when doctors exist but the current search or filter hides them all.
  bool get isFilteredEmpty =>
      _allDoctors.isNotEmpty && visibleDoctors.isEmpty && !_isLoading;

  Future<void> load({String? specialityId, bool availableNow = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allDoctors = await _getDoctors(
        specialityId: specialityId,
        availableNow: availableNow,
      );
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void changeQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  void changeFilter(DoctorListFilter value) {
    if (value == _filter) return;
    _filter = value;
    notifyListeners();
  }
}
