import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/bank_account.dart';
import '../../domain/entities/doctor_application.dart';
import '../../domain/entities/doctor_credentials.dart';
import '../../domain/entities/doctor_setup_options.dart';
import '../../domain/entities/doctor_setup_step.dart';
import '../../domain/entities/medical_certificate.dart';
import '../../domain/usecases/get_doctor_setup_options.dart';
import '../../domain/usecases/parse_medical_certificate.dart';
import '../../domain/usecases/submit_doctor_application.dart';

/// Presentation state for the three-step doctor profile setup.
///
/// One controller spans all three steps: they share the certificate, the
/// credentials it filled in and the payout details, and the stepper has to know
/// how far along the whole thing is.
class DoctorSetupController extends ChangeNotifier {
  DoctorSetupController(
    this._getSetupOptions,
    this._parseCertificate,
    this._submitApplication,
  );

  final GetDoctorSetupOptions _getSetupOptions;
  final ParseMedicalCertificate _parseCertificate;
  final SubmitDoctorApplication _submitApplication;

  DoctorSetupStep _step = DoctorSetupStep.uploadVerify;
  DoctorSetupStep get step => _step;

  DoctorSetupOptions _options = const DoctorSetupOptions();
  DoctorSetupOptions get options => _options;

  MedicalCertificate? _certificate;
  MedicalCertificate? get certificate => _certificate;

  DoctorCredentials _credentials = const DoctorCredentials();
  DoctorCredentials get credentials => _credentials;

  BankAccount _bankAccount = const BankAccount();
  BankAccount get bankAccount => _bankAccount;

  bool _isParsing = false;

  /// True while the certificate is being read — the upload card shows this.
  bool get isParsing => _isParsing;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  /// Held back until a submit is attempted, so the form is not red while it is
  /// still being filled in.
  bool _showErrors = false;
  bool get showErrors => _showErrors;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// True once the certificate has been read and the fields filled in.
  bool get isAutoFilled => _credentials.isAutoFilled;

  /// True once a certificate has been accepted for this registration.
  bool get hasCertificate => _certificate != null;

  bool get isStepComplete => switch (_step) {
    // **The certificate is the registration.** It used to be skippable, and
    // a skipped upload meant a doctor could type a registration number by
    // hand, file the form and be walked into the doctor app with nothing
    // behind their credentials that a reviewer had ever seen. Nobody
    // reaches the details step without a file now.
    DoctorSetupStep.uploadVerify => hasCertificate,
    DoctorSetupStep.details => _credentials.isComplete,
    DoctorSetupStep.bank => _bankAccount.isComplete,
  };

  /// A step the doctor has already been through, which the stepper ticks.
  bool isStepDone(DoctorSetupStep step) => step.index < _step.index;

  Future<void> loadOptions() async {
    if (_options.states.isNotEmpty) return;

    try {
      _options = await _getSetupOptions();
      notifyListeners();
    } on Failure catch (failure) {
      // The dropdowns come back empty; the doctor can still retry the screen.
      _errorMessage = failure.message;
      notifyListeners();
    }
  }

  // --- Step 1: the certificate --------------------------------------------

  /// Reads [certificate] and pre-fills the details step from it.
  Future<bool> uploadCertificate(MedicalCertificate certificate) async {
    if (_isParsing) return false;

    _isParsing = true;
    _errorMessage = null;
    _certificate = certificate;
    notifyListeners();

    try {
      final parsed = await _parseCertificate(certificate);
      // Anything the doctor already typed stays; the parse fills the rest.
      _credentials = parsed;
      return true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      _certificate = null;
      return false;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      _certificate = null;
      return false;
    } finally {
      _isParsing = false;
      notifyListeners();
    }
  }

  /// Drops the uploaded file, leaving the details to be typed by hand.
  void clearCertificate() {
    if (_certificate == null) return;

    _certificate = null;
    notifyListeners();
  }

  // --- Navigation ---------------------------------------------------------

  /// Moves to the next step, or reports that this one is not finished.
  bool goToNextStep() {
    if (!isStepComplete) {
      _showErrors = true;

      // Said here rather than left to the screen: the upload step has no field
      // to turn red, so without a message a disabled Continue is the only
      // feedback a doctor gets, and it explains nothing.
      if (_step == DoctorSetupStep.uploadVerify) {
        _errorMessage =
            'Upload your medical certificate to continue. '
            'A PDF or a photo of the document is fine.';
      }

      notifyListeners();
      return false;
    }

    final next = _step.next;
    if (next == null) return false;

    _step = next;
    _showErrors = false;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Steps back. Returns false on the first step, where the screen itself
  /// should be popped instead.
  bool goToPreviousStep() {
    final previous = _step.previous;
    if (previous == null) return false;

    _step = previous;
    _showErrors = false;
    notifyListeners();
    return true;
  }

  // --- Step 2: the details -------------------------------------------------

  void changeCredentials(DoctorCredentials Function(DoctorCredentials) update) {
    _credentials = update(_credentials);
    notifyListeners();
  }

  void changeState(String? state) {
    if (state == null || state == _credentials.state) return;
    // A city from the old state would be wrong, so it goes.
    _credentials = _credentials.copyWith(state: state, clearCity: true);
    notifyListeners();
  }

  // --- Step 3: the payout account -----------------------------------------

  void changeBankAccount(BankAccount Function(BankAccount) update) {
    _bankAccount = update(_bankAccount);
    notifyListeners();
  }

  /// Files the registration. Returns the application, or null when the form or
  /// the network said no.
  Future<DoctorApplication?> submit() async {
    if (_isSubmitting) return null;

    // The certificate is checked again here, not only at the step that
    // collected it. A registration filed without one is a registration a
    // reviewer cannot decide, and this method is reachable from anywhere.
    if (_certificate == null) {
      _step = DoctorSetupStep.uploadVerify;
      _showErrors = true;
      _errorMessage = 'Your medical certificate is required to register.';
      notifyListeners();
      return null;
    }

    if (!_bankAccount.isComplete || !_credentials.isComplete) {
      _showErrors = true;
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _submitApplication(
        credentials: _credentials,
        bankAccount: _bankAccount,
        // Non-null by the guard above, which is the point of the guard: the
        // use case now requires one, so an unfiled certificate is a compile
        // error rather than a registration a reviewer cannot act on.
        certificate: _certificate!,
      );
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      return null;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
