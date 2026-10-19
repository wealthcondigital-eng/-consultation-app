import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor_earnings.dart';
import '../../domain/usecases/manage_doctor_practice.dart';

/// Presentation state for the earnings screen.
class DoctorEarningsController extends ChangeNotifier {
  DoctorEarningsController(this._getEarnings);

  final GetDoctorEarnings _getEarnings;

  /// Seeded on the same period the screen opens on, so the segmented control
  /// and the (empty) figures under it agree before the first read lands.
  DoctorEarnings _earnings = const DoctorEarnings(period: EarningsPeriod.today);
  DoctorEarnings get earnings => _earnings;

  /// Opens on today.
  ///
  /// It used to open on the month, on the reasoning that a slow afternoon makes
  /// a dull screen. But the question a doctor opens this screen to answer is
  /// "what have I made today" — the month is a figure they look up, and today
  /// is one they check. The other three periods are one tap away either way,
  /// and a zero this morning is a true answer rather than a dull one.
  EarningsPeriod _period = EarningsPeriod.today;
  EarningsPeriod get period => _period;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;

  /// True once the figures have been read at least once.
  ///
  /// What lets the screen tell a failed read — nothing to show, so an error
  /// page — from a failed refresh, where last minute's figures are still worth
  /// showing above an inline retry.
  bool get hasLoaded => _hasLoaded;

  bool get isInitialLoad => _isLoading && !_hasLoaded;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _earnings = await _getEarnings(_period);
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

  /// Switches period and reloads.
  ///
  /// The figures are cleared first, so the headline number never sits under a
  /// heading it does not belong to — a month's total labelled "Today" is worse
  /// than a spinner for half a second.
  Future<void> setPeriod(EarningsPeriod period) async {
    if (period == _period) return;

    _period = period;
    _earnings = DoctorEarnings(period: period);
    _hasLoaded = false;
    notifyListeners();

    await load();
  }

  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
