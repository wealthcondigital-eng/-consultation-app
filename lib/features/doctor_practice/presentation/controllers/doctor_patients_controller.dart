import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor_patient.dart';
import '../../domain/usecases/manage_doctor_practice.dart';

/// Presentation state for the doctor's patient roster.
class DoctorPatientsController extends ChangeNotifier {
  DoctorPatientsController(this._getPatients);

  final GetDoctorPatients _getPatients;

  /// How long after the last keystroke the search actually runs. Short enough
  /// to feel immediate, long enough that typing a name is one request rather
  /// than one per letter.
  static const Duration searchDebounce = Duration(milliseconds: 350);

  List<DoctorPatient> _patients = const [];
  List<DoctorPatient> get patients => _patients;

  String _search = '';
  String get search => _search;

  Timer? _debounce;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;
  bool get isInitialLoad => _isLoading && !_hasLoaded;

  bool get isEmpty => _hasLoaded && _patients.isEmpty;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  @override
  void dispose() {
    // Otherwise a keystroke half a second before the screen closes fires a
    // request against a disposed controller.
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _patients = await _getPatients(search: _search);
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

  /// Records the query and schedules the search.
  ///
  /// The field updates immediately — the text a doctor typed must appear as
  /// they type it — and only the request waits.
  void setSearch(String value) {
    if (value == _search) return;

    _search = value;
    notifyListeners();

    _debounce?.cancel();
    _debounce = Timer(searchDebounce, load);
  }

  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
