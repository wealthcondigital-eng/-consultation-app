import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/logging/auth_logger.dart';
import '../../../../core/media/profile_photo_picker.dart';
import '../../../auth/domain/usecases/sign_out.dart';
import '../../../home/domain/entities/patient_dashboard.dart';
import '../../../home/domain/usecases/get_patient_dashboard.dart';
import '../../domain/entities/patient_account.dart';
import '../../domain/usecases/get_patient_account.dart';
import '../../domain/usecases/manage_profile_photo.dart';

/// Presentation state for My Profile.
class PatientProfileController extends ChangeNotifier {
  PatientProfileController(
    this._getPatientAccount,
    this._signOut,
    this._managePhoto,
    this._picker,
    this._getDashboard,
  );

  final GetPatientAccount _getPatientAccount;
  final SignOut _signOut;
  final ManageProfilePhoto _managePhoto;
  final ProfilePhotoPicker _picker;

  /// The running totals and the completeness figure, which moved here from the
  /// dashboard. Read alongside the account rather than instead of it: the two
  /// answer different questions and come from different endpoints.
  final GetPatientDashboard _getDashboard;

  PatientAccount? _account;
  PatientAccount? get account => _account;

  /// Null until the figures arrive, and stays null if they fail — the profile
  /// is perfectly readable without them, so the stats card is simply absent
  /// rather than the screen being an error.
  PatientDashboard? _dashboard;
  PatientDashboard? get dashboard => _dashboard;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get isInitialLoad => _isLoading && _account == null;

  bool _isSigningOut = false;
  bool get isSigningOut => _isSigningOut;

  /// True while a photo is being picked, uploaded or removed. The avatar shows
  /// a spinner over itself rather than the screen going blank — the rest of the
  /// profile is still perfectly readable.
  bool _isSavingPhoto = false;
  bool get isSavingPhoto => _isSavingPhoto;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Both at once rather than one after the other: they are independent
    // reads, and a profile that takes two round trips to open on a phone
    // connection takes twice as long to open.
    final figures = _loadDashboard();

    try {
      _account = await _getPatientAccount();
      _dashboard = await figures;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Puts the record the edit form saved on screen, then refreshes the figures.
  ///
  /// [stored] is what the server answered the save with, so the account itself
  /// needs no second read. The figures do: the completeness percentage is
  /// worked out from the fields that just changed.
  Future<void> applySavedAccount(PatientAccount stored) async {
    // The photo path the avatar already holds, when there still is a photo.
    // It carries the version that stops the avatar re-downloading the same
    // bytes; the server's copy is the bare path.
    final currentPhoto = _account?.avatarUrl;
    _account = stored.avatarUrl != null && currentPhoto != null
        ? stored.copyWith(avatarUrl: currentPhoto)
        : stored;
    _errorMessage = null;
    notifyListeners();

    final figures = await _loadDashboard();
    if (figures != null) {
      _dashboard = figures;
      notifyListeners();
    }
  }

  /// The figures, or null when they could not be read.
  ///
  /// Never throws: the account is what this screen is *for*, and losing three
  /// running totals must not turn a readable profile into an error page.
  Future<PatientDashboard?> _loadDashboard() async {
    try {
      return await _getDashboard();
    } catch (error) {
      // Quiet on screen, loud in the log: a stats card left on its previous
      // figures looks exactly like a profile that did not save.
      AuthLogger.event('API · patient dashboard failed', {'error': error});
      return null;
    }
  }

  /// Picks a photo and uploads it.
  ///
  /// A cancelled picker is not an error and not a state change: the method
  /// simply returns, and nothing on screen moves. Only the upload gets a
  /// spinner, because only the upload takes time the person is waiting on.
  Future<void> changePhoto(PhotoSource source) async {
    if (_isSavingPhoto) return;

    final PickedPhoto? picked;
    try {
      picked = await _picker.pick(source);
    } catch (_) {
      // The plugin refusing — a denied camera permission is the usual cause.
      _errorMessage =
          'Could not open that. Check the app has permission and try again.';
      notifyListeners();
      return;
    }

    if (picked == null) return;

    _isSavingPhoto = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final path = await _managePhoto.upload(picked.localPath);
      // Folded into the account in place rather than re-reading it. The server
      // answered with the path it stored, which is the only field that changed.
      // The path is the same for every photo, so a version is added to it:
      // that is what tells `RemoteAvatar` to fetch the new one.
      _account = _account?.copyWith(avatarUrl: _versioned(path));
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isSavingPhoto = false;
      notifyListeners();
    }
  }

  Future<void> removePhoto() async {
    if (_isSavingPhoto || _account?.avatarUrl == null) return;

    _isSavingPhoto = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _managePhoto.remove();
      _account = _account?.copyWith(clearAvatar: true);
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isSavingPhoto = false;
      notifyListeners();
    }
  }

  /// Ends the session. Returns true when the screen should leave for the
  /// landing page.
  ///
  /// A failure here still signs the patient out locally — leaving them on a
  /// screen full of their own data would be the worse outcome.
  Future<bool> signOut() async {
    if (_isSigningOut) return false;

    _isSigningOut = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _signOut();
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }

    return true;
  }

  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}

/// `/patients/me/photo` → `/patients/me/photo?v=1727241600000`. The server
/// ignores the query; the avatar sees a new path and fetches again.
String? _versioned(String? path) =>
    path == null ? null : '$path?v=${DateTime.now().millisecondsSinceEpoch}';
