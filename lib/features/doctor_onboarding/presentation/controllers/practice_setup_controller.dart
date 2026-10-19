import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/practice_setup.dart';
import '../../domain/usecases/manage_practice_setup.dart';

/// Presentation state for the setup wizard's consultation fee step.
///
/// Holds two fees rather than one. The screen used to collect a single amount
/// and write it to both, which priced a voice call the same as a video one.
class PracticeSetupController extends ChangeNotifier {
  PracticeSetupController(this._managePracticeSetup);

  final ManagePracticeSetup _managePracticeSetup;

  PracticeSetup _setup = const PracticeSetup();
  PracticeSetup get setup => _setup;

  /// What the last read returned, for the dirty check. Never shown.
  PracticeSetup _stored = const PracticeSetup();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;

  /// True once the read has come back, whatever it said.
  ///
  /// The spinner used to be `_isLoading && feeOptions.isEmpty`, and the options
  /// came from the backend — so a failed read left the screen with no chips, no
  /// fee, a permanently disabled Continue and nothing said about why. It now
  /// turns on a flag that a failure also sets, and the options are the app's.
  bool get hasLoaded => _hasLoaded;

  bool get isInitialLoad => _isLoading && !_hasLoaded;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  /// True once the doctor has tried to save. Field errors show from then on,
  /// rather than greeting them with complaints about fields they have not
  /// touched.
  bool _showErrors = false;
  bool get showErrors => _showErrors;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// True when at least one fee is set and every set fee is in range.
  bool get isValid {
    if (_setup.videoFee == null && _setup.audioFee == null) return false;

    return ConsultationFeeKind.values.every(
      (kind) => kind.errorFor(_setup) == null,
    );
  }

  bool get canSave => isValid && !_isSaving;

  /// True when the form holds something the server does not, so a doctor who
  /// changed nothing is not made to save again on the way through the wizard.
  bool get isDirty =>
      _setup.videoFee != _stored.videoFee ||
      _setup.audioFee != _stored.audioFee;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _stored = await _managePracticeSetup.load();
      // Seeded with the platform's suggestion where nothing is stored. In the
      // *form* only — `PracticeSetup` deliberately leaves the record's fees
      // null, because a default written into a record is indistinguishable
      // from a price the doctor chose.
      _setup = _stored.copyWith(
        videoFee: _stored.videoFee ?? ConsultationFeeKind.video.suggested,
        audioFee: _stored.audioFee ?? ConsultationFeeKind.audio.suggested,
      );
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      // The suggestion, so the screen is still usable and the doctor can save
      // — the read failing is not a reason they cannot set a price.
      _setup = const PracticeSetup().copyWith(
        videoFee: ConsultationFeeKind.video.suggested,
        audioFee: ConsultationFeeKind.audio.suggested,
      );
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      _setup = const PracticeSetup().copyWith(
        videoFee: ConsultationFeeKind.video.suggested,
        audioFee: ConsultationFeeKind.audio.suggested,
      );
    } finally {
      _hasLoaded = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets one of the two fees. Null clears it, which prices only the other.
  void setFee(ConsultationFeeKind kind, int? amount) {
    if (amount == kind.from(_setup)) return;

    _setup = kind.applyTo(_setup, amount);
    _errorMessage = null;
    notifyListeners();
  }

  /// Prices audio the same as video — the common case, and one tap rather than
  /// re-typing a number the doctor has already entered.
  void matchAudioToVideo() {
    final video = _setup.videoFee;
    if (video == null) return;

    setFee(ConsultationFeeKind.audio, video);
  }

  /// Saves both fees. Returns true when the wizard can move on.
  ///
  /// A form that has not changed counts as saved. Otherwise a doctor stepping
  /// back through the wizard has to re-save a price that is already stored, and
  /// a failed write there would block a step that had nothing to write.
  Future<bool> save() async {
    if (_isSaving) return false;

    if (!isValid) {
      _showErrors = true;
      _errorMessage = _setup.videoFee == null && _setup.audioFee == null
          ? 'Set a video or an audio consultation fee.'
          : ConsultationFeeKind.values
                .map((kind) => kind.errorFor(_setup))
                .whereType<String>()
                .firstOrNull;
      notifyListeners();
      return false;
    }

    if (!isDirty) return true;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _managePracticeSetup.saveFees(
        videoFee: _setup.videoFee,
        audioFee: _setup.audioFee,
      );
      _stored = _setup;
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
