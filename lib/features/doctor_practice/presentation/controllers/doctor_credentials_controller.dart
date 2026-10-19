import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../doctor_onboarding/data/datasources/certificate_picker.dart';
import '../../../doctor_onboarding/domain/entities/medical_certificate.dart';
import '../../domain/entities/doctor_credential.dart';
import '../../domain/entities/doctor_practice_profile.dart';
import '../../domain/usecases/manage_doctor_practice.dart';

/// Presentation state for Credentials & Documents.
///
/// Reads the profile as well as the documents, because the screen has to show
/// both halves of the same fact: what was uploaded, and what the review made of
/// the application as a whole. A doctor whose certificate was accepted but
/// whose registration is still under review needs to see both, not one.
class DoctorCredentialsController extends ChangeNotifier {
  DoctorCredentialsController(
    this._getCredentials,
    this._manageProfile,
    this._picker,
  );

  final GetDoctorCredentials _getCredentials;
  final ManageDoctorProfile _manageProfile;

  /// The camera and the file browser, behind an interface — a widget test has
  /// neither, and a screen calling the plugin directly is a screen no test can
  /// drive.
  final CertificatePicker _picker;

  /// The file the doctor has chosen for the certificate they are adding, before
  /// it is sent. Null until they pick one.
  MedicalCertificate? _pending;
  MedicalCertificate? get pendingFile => _pending;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  List<DoctorCredential> _credentials = const [];
  List<DoctorCredential> get credentials => _credentials;

  DoctorPracticeProfile? _profile;
  DoctorPracticeProfile? get profile => _profile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;
  bool get isInitialLoad => _isLoading && !_hasLoaded;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Started together: the card and the list are independent reads, and two
    // round trips in series is twice the wait for one screen.
    final credentials = _getCredentials();
    final profile = _manageProfile.load();

    try {
      _credentials = await credentials;
      _profile = await profile;
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

  /// Opens the picker and holds what comes back.
  ///
  /// Returns null when the doctor backs out, which is not an error — and when
  /// the file cannot be used, in which case [errorMessage] says why. A file
  /// that is too big or of the wrong type is caught here rather than at upload,
  /// so they find out at the moment they picked it.
  Future<MedicalCertificate?> pickFile(CertificateSource source) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final picked = await _picker.pick(source);
      if (picked == null) return null;

      if (picked.rejectionReason case final reason?) {
        _errorMessage = reason;
        notifyListeners();
        return null;
      }

      _pending = picked;
      notifyListeners();
      return picked;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      notifyListeners();
      return null;
    } catch (_) {
      _errorMessage = 'That file could not be read. Please try another.';
      notifyListeners();
      return null;
    }
  }

  void clearPendingFile() {
    if (_pending == null) return;
    _pending = null;
    notifyListeners();
  }

  /// Files the chosen certificate, awaiting review. Returns true when it lands.
  Future<bool> addCertificate(String title) async {
    final certificate = _pending;
    if (certificate == null || _isSaving) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final added = await _getCredentials.add(
        title: title,
        certificate: certificate,
      );

      // Prepended rather than re-read: the list is sorted newest first, and a
      // full reload for one row the server just echoed back is a round trip
      // that shows the doctor a spinner over a screen they were reading.
      _credentials = [added, ..._credentials];
      _pending = null;
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

  /// Withdraws a certificate the doctor added. Returns true when it is gone.
  Future<bool> removeCertificate(DoctorCredential credential) async {
    if (_isSaving) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _getCredentials.remove(credential);
      _credentials = [
        for (final row in _credentials)
          if (row.id != credential.id) row,
      ];
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

  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
