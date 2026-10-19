import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/blood_group.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/patient_account.dart';
import '../../domain/entities/patient_details.dart';
import '../../domain/usecases/update_patient_details.dart';

/// Presentation state for editing My Profile.
class EditProfileController extends ChangeNotifier {
  EditProfileController(this._updatePatientDetails);

  final UpdatePatientDetails _updatePatientDetails;

  late PatientDetails _details;
  PatientDetails get details => _details;

  /// The values the form opened with, so Save can be disabled until something
  /// actually changes.
  late PatientDetails _original;

  /// The phone number, shown but not editable — it is the verified identity.
  late String phoneNumber;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  /// Errors appear only after a failed save attempt, so the form does not
  /// scold someone who is still typing their name.
  bool _showErrors = false;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// The record as the server stored it, after a successful [save]. Null
  /// before one, and when the backend answered without the record.
  PatientAccount? _savedAccount;
  PatientAccount? get savedAccount => _savedAccount;

  void start(PatientAccount account) {
    _details = PatientDetails.from(account);
    _original = _details;
    phoneNumber = account.phoneNumber;
  }

  String? get nameError =>
      _showErrors && !_details.hasValidName ? 'Enter your full name.' : null;

  String? get emailError => _showErrors && !_details.hasValidEmail
      ? 'Enter a valid email address.'
      : null;

  String? get dateOfBirthError =>
      _showErrors && !_details.isValidDateOfBirth(DateTime.now())
      ? 'Enter a real date of birth.'
      : null;

  bool get hasChanges =>
      _details.fullName != _original.fullName ||
      _details.email != _original.email ||
      _details.dateOfBirth != _original.dateOfBirth ||
      _details.gender != _original.gender ||
      _details.bloodGroup != _original.bloodGroup;

  bool get canSave => hasChanges && !_isSaving;

  void changeFullName(String value) =>
      _update(_details.copyWith(fullName: value));

  void changeEmail(String value) => _update(_details.copyWith(email: value));

  void changeDateOfBirth(DateTime? value) => _update(
    value == null
        ? _details.copyWith(clearDateOfBirth: true)
        : _details.copyWith(dateOfBirth: value),
  );

  void changeGender(Gender? value) => _update(_details.copyWith(gender: value));

  void changeBloodGroup(BloodGroup? value) =>
      _update(_details.copyWith(bloodGroup: value));

  /// True when the edits were stored and the screen should close.
  Future<bool> save() async {
    if (_isSaving) return false;

    _showErrors = true;
    if (!_details.isComplete(DateTime.now())) {
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _savedAccount = await _updatePatientDetails(_details);
      _original = _details;
      return true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      return false;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _update(PatientDetails next) {
    _details = next;
    _errorMessage = null;
    notifyListeners();
  }
}
