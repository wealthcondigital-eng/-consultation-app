import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor_practice_profile.dart';
import '../../domain/usecases/manage_doctor_practice.dart';

/// Presentation state for the doctor's edit-profile form.
///
/// Loads the stored profile itself rather than taking it as an argument, so the
/// form always opens on what the server holds — a profile passed down from a
/// screen that loaded ten minutes ago is a form that silently reverts whatever
/// changed since.
class DoctorProfileEditController extends ChangeNotifier {
  DoctorProfileEditController(this._manage);

  final ManageDoctorProfile _manage;

  DoctorPracticeProfile? _profile;

  /// The stored record, for the read-only rows the form shows but cannot
  /// change — the registration number and the degree.
  DoctorPracticeProfile? get profile => _profile;

  DoctorProfileEdits _edits = const DoctorProfileEdits();
  DoctorProfileEdits get edits => _edits;

  DoctorProfileEdits _original = const DoctorProfileEdits();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get isInitialLoad => _isLoading && _profile == null;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  /// True once the doctor has tried to save, which is when the field errors
  /// start showing. Marking a field red before anyone has typed in it is how a
  /// form greets someone with three complaints.
  bool _showErrors = false;
  bool get showErrors => _showErrors;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isDirty => !_matches(_edits, _original);

  bool get canSave => isDirty && !_isSaving;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _manage.load();
      _profile = profile;
      _original = DoctorProfileEdits.from(profile);
      _edits = _original;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFullName(String value) => _update(_edits.copyWith(fullName: value));

  void setEmail(String value) => _update(_edits.copyWith(email: value));

  void setState_(String value) => _update(_edits.copyWith(state: value));

  void setCity(String value) => _update(_edits.copyWith(city: value));

  void setBio(String value) => _update(_edits.copyWith(bio: value));

  /// Blank clears it, which is different from "unchanged" — a doctor who
  /// empties the field means they would rather not say.
  void setYearsOfExperience(String value) {
    final trimmed = value.trim();

    _update(
      trimmed.isEmpty
          ? _edits.copyWith(clearYears: true)
          : _edits.copyWith(yearsOfExperience: int.tryParse(trimmed)),
    );
  }

  void toggleLanguage(String language) {
    final current = _edits.languages;
    final has = current.any(
      (entry) => entry.toLowerCase() == language.toLowerCase(),
    );

    _update(
      _edits.copyWith(
        languages: has
            ? current
                  .where(
                    (entry) => entry.toLowerCase() != language.toLowerCase(),
                  )
                  .toList()
            : [...current, language],
      ),
    );
  }

  /// Saves, and returns the stored profile when it went through.
  ///
  /// The profile rather than a bool, so the screen behind can fold it in
  /// instead of re-reading a page the app just wrote.
  Future<DoctorPracticeProfile?> save() async {
    if (_isSaving) return null;

    if (!_edits.isValid) {
      _showErrors = true;
      notifyListeners();
      return null;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final saved = await _manage.save(_edits);
      _profile = saved;
      _original = DoctorProfileEdits.from(saved);
      _edits = _original;
      return saved;
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

  void _update(DoctorProfileEdits edits) {
    _edits = edits;
    notifyListeners();
  }

  /// Field by field, because [DoctorProfileEdits] holds a list and two equal
  /// lists are not the same object.
  static bool _matches(DoctorProfileEdits a, DoctorProfileEdits b) {
    if (a.languages.length != b.languages.length) return false;
    for (var index = 0; index < a.languages.length; index += 1) {
      if (a.languages[index] != b.languages[index]) return false;
    }

    return a.fullName == b.fullName &&
        a.email == b.email &&
        a.state == b.state &&
        a.city == b.city &&
        a.yearsOfExperience == b.yearsOfExperience &&
        a.bio == b.bio;
  }
}
