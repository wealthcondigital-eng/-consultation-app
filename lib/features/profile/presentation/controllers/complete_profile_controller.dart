import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/usecases/save_patient_profile.dart';

/// What a submit attempt did, so the screen knows which way to tell the user.
enum CompleteProfileOutcome {
  saved,

  /// Something is missing or malformed; the inline field errors explain it.
  invalid,

  /// The date of birth is real but under 18. Gets its own dialog rather than a
  /// red line under a field, because it ends the sign-up rather than asking
  /// for a correction.
  underage,

  /// The save was attempted and the backend or network refused it.
  failed,
}

/// Presentation state for the complete-profile form.
///
/// Field errors stay hidden until the first submit, then update live as the
/// user fixes them — so the form never scolds someone who has not finished
/// filling it in, and never leaves them guessing after they have.
class CompleteProfileController extends ChangeNotifier {
  CompleteProfileController(
    this._savePatientProfile, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SavePatientProfile _savePatientProfile;

  /// Injectable so the age boundary is testable without waiting for a birthday.
  final DateTime Function() _clock;

  String _fullName = '';
  DateTime? _dateOfBirth;
  Gender? _gender;
  bool _dataProcessingConsent = false;
  bool _termsAccepted = false;

  bool _submitAttempted = false;
  bool _isSaving = false;

  String? _errorMessage;

  String get fullName => _fullName;
  DateTime? get dateOfBirth => _dateOfBirth;
  Gender? get gender => _gender;
  bool get dataProcessingConsent => _dataProcessingConsent;
  bool get termsAccepted => _termsAccepted;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  PatientProfile get profile => PatientProfile(
    fullName: _fullName,
    dateOfBirth: _dateOfBirth,
    gender: _gender,
    dataProcessingConsent: _dataProcessingConsent,
    termsAccepted: _termsAccepted,
  );

  bool get canSubmit => !_isSaving;

  /// Whole years, for the dialog copy. Null until a date is picked.
  int? get age => profile.ageAt(_clock());

  // --- Field errors --------------------------------------------------------
  // All null until the user has tried to submit at least once.

  String? get nameError {
    if (!_submitAttempted || profile.hasValidName) return null;
    return 'Enter your full name.';
  }

  /// Covers the missing and the impossible date. Being under 18 is *not* an
  /// error here — it is handled by [CompleteProfileOutcome.underage], so the
  /// field does not contradict the dialog.
  String? get dateOfBirthError {
    if (!_submitAttempted) return null;
    if (_dateOfBirth == null) return 'Select your date of birth.';
    if (!profile.isDateOfBirthPlausible(_clock())) {
      return 'Enter a real date of birth.';
    }
    return null;
  }

  String? get genderError {
    if (!_submitAttempted || _gender != null) return null;
    return 'Select your gender.';
  }

  String? get dataProcessingConsentError {
    if (!_submitAttempted || _dataProcessingConsent) return null;
    return 'This consent is required to continue.';
  }

  String? get termsAcceptedError {
    if (!_submitAttempted || _termsAccepted) return null;
    return 'You must accept the terms to continue.';
  }

  // --- Mutations -----------------------------------------------------------

  void changeFullName(String value) {
    _fullName = value;
    _notifyIfValidating();
  }

  void changeDateOfBirth(DateTime value) {
    _dateOfBirth = value;
    notifyListeners();
  }

  void changeGender(Gender? value) {
    if (value == null || value == _gender) return;
    _gender = value;
    notifyListeners();
  }

  void changeDataProcessingConsent(bool value) {
    _dataProcessingConsent = value;
    notifyListeners();
  }

  void changeTermsAccepted(bool value) {
    _termsAccepted = value;
    notifyListeners();
  }

  /// Text edits only need a rebuild once errors are on screen — the field
  /// paints its own characters.
  void _notifyIfValidating() {
    if (_submitAttempted) notifyListeners();
  }

  /// Validates, saves, and reports what happened.
  ///
  /// The age check runs **before** [_savePatientProfile], so a minor's name,
  /// date of birth and gender are never sent anywhere. That ordering is the
  /// point of the gate, not an optimisation.
  Future<CompleteProfileOutcome> submit() async {
    if (_isSaving) return CompleteProfileOutcome.invalid;

    _submitAttempted = true;
    _errorMessage = null;

    final now = _clock();

    if (!profile.isComplete(now)) {
      notifyListeners();

      // Only call it underage when everything else is in order — otherwise a
      // half-filled form would pop a dialog about a birthday.
      final onlyAgeFails =
          profile.hasValidName &&
          profile.isDateOfBirthPlausible(now) &&
          !profile.isOldEnough(now) &&
          _gender != null &&
          _dataProcessingConsent &&
          _termsAccepted;

      return onlyAgeFails
          ? CompleteProfileOutcome.underage
          : CompleteProfileOutcome.invalid;
    }

    _isSaving = true;
    notifyListeners();

    try {
      await _savePatientProfile(profile);
      return CompleteProfileOutcome.saved;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      return CompleteProfileOutcome.failed;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      return CompleteProfileOutcome.failed;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
