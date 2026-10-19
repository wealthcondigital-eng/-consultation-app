import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/l10n/tr.dart';
import '../../domain/entities/medical_history.dart';
import '../../domain/usecases/manage_medical_history.dart';

/// Presentation state for the medical-history form.
///
/// Holds the record being edited rather than the record as stored, so a
/// half-finished edit survives a rebuild and the Save button can tell whether
/// anything actually changed. [isDirty] is what makes leaving without saving a
/// question rather than a silent loss.
class MedicalHistoryController extends ChangeNotifier {
  MedicalHistoryController(this._manage);

  final ManageMedicalHistory _manage;

  MedicalHistory _history = const MedicalHistory.empty();
  MedicalHistory get history => _history;

  /// What was loaded, for the dirty check. Never shown.
  MedicalHistory _stored = const MedicalHistory.empty();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;
  bool get isInitialLoad => _isLoading && !_hasLoaded;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// True when the form holds something the server does not.
  bool get isDirty => !_matches(_history, _stored);

  bool get canSave => isDirty && !_isSaving;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _stored = await _manage.load();
      _history = _stored;
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

  /// Adds an entry to one section.
  ///
  /// Trimmed, and a duplicate is dropped rather than refused: the person typed
  /// something they already have, and an error message about it would be
  /// pedantry. Compared case-insensitively, because "Asthma" and "asthma" are
  /// one condition.
  void addEntry(MedicalHistorySection section, String value) {
    final entry = value.trim();
    if (entry.isEmpty) return;

    final current = section.from(_history);
    final exists = current.any(
      (existing) => existing.toLowerCase() == entry.toLowerCase(),
    );
    if (exists) return;

    if (current.length >= ManageMedicalHistory.maxEntriesPerSection) {
      _errorMessage = tr('You can list up to {count} {section}.', {
        'count': ManageMedicalHistory.maxEntriesPerSection,
        'section': tr(section.label).toLowerCase(),
      });
      notifyListeners();
      return;
    }

    _history = section.applyTo(_history, [...current, entry]);
    _errorMessage = null;
    notifyListeners();
  }

  void removeEntry(MedicalHistorySection section, String value) {
    final current = section.from(_history);
    if (!current.contains(value)) return;

    _history = section.applyTo(
      _history,
      current.where((entry) => entry != value).toList(),
    );
    notifyListeners();
  }

  void setNotes(String value) {
    final notes = value.trim();
    if ((_history.notes ?? '') == notes) return;

    _history = notes.isEmpty
        ? _history.copyWith(clearNotes: true)
        : _history.copyWith(notes: notes);
    notifyListeners();
  }

  /// Saves, and returns the stored record when it went through.
  ///
  /// The record rather than a bool, because the profile screen folds it back
  /// into the account it is already holding — the alternative is a second read
  /// of a page the app just wrote.
  Future<MedicalHistory?> save() async {
    if (_isSaving) return null;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _stored = await _manage.save(_history);
      _history = _stored;
      return _stored;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isSaving = false;
      notifyListeners();
    }

    return null;
  }

  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Field-by-field, because [MedicalHistory] holds lists and two equal lists
  /// are not the same object. `lastUpdated` is left out on purpose: the server
  /// stamps it, so comparing it would make every loaded record read as dirty.
  static bool _matches(MedicalHistory a, MedicalHistory b) {
    bool sameList(List<String> x, List<String> y) {
      if (x.length != y.length) return false;
      for (var index = 0; index < x.length; index += 1) {
        if (x[index] != y[index]) return false;
      }
      return true;
    }

    return sameList(a.conditions, b.conditions) &&
        sameList(a.medications, b.medications) &&
        sameList(a.allergies, b.allergies) &&
        sameList(a.surgeries, b.surgeries) &&
        (a.notes ?? '') == (b.notes ?? '');
  }
}
