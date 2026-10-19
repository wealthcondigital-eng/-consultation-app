import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/media/profile_photo_picker.dart';
import '../../../auth/domain/usecases/sign_out.dart';
import '../../../doctor_practice/domain/usecases/manage_doctor_practice.dart';
import '../../../doctor_onboarding/domain/entities/doctor_availability.dart';
import '../../../doctor_onboarding/domain/entities/practice_setup.dart';
import '../../../doctor_onboarding/domain/usecases/manage_availability.dart';
import '../../../doctor_onboarding/domain/usecases/manage_practice_setup.dart';
import '../../../home/domain/entities/doctor_dashboard.dart';
import '../../../home/domain/usecases/manage_doctor_dashboard.dart';

/// Presentation state for the doctor's profile.
///
/// Composed of three reads the app already had rather than a profile endpoint
/// of its own: who the doctor is comes from the dashboard, and the two rows
/// that carry a value — their schedule and their fee — come from the settings
/// those rows lead to. Anything less and the rows would be bare chevrons.
class DoctorProfileController extends ChangeNotifier {
  DoctorProfileController(
    this._manageDashboard,
    this._manageAvailability,
    this._managePractice,
    this._signOut,
    this._manageProfile,
    this._picker,
  );

  final ManageDoctorDashboard _manageDashboard;
  final ManageAvailability _manageAvailability;
  final ManagePracticeSetup _managePractice;
  final SignOut _signOut;

  /// Only for the photo. The rest of the doctor's profile is edited on its own
  /// screen, which has a controller of its own.
  final ManageDoctorProfile _manageProfile;
  final ProfilePhotoPicker _picker;

  DoctorDashboard? _dashboard;
  DoctorDashboard? get dashboard => _dashboard;

  /// Null while it has not been read, or when the read failed — the row then
  /// shows no summary rather than a wrong one.
  DoctorAvailability? _availability;
  DoctorAvailability? get availability => _availability;

  PracticeSetup? _practice;
  PracticeSetup? get practice => _practice;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get isInitialLoad => _isLoading && _dashboard == null;

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

    // Started together: the screen is a stack of independent cards, not a
    // sequence of steps, and three round trips in series is three times the
    // wait for no reason.
    final dashboard = _manageDashboard.load();
    final availability = _quiet(_manageAvailability.load);
    final practice = _quiet(_managePractice.load);

    try {
      _dashboard = await dashboard;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    }

    _availability = await availability;
    _practice = await practice;

    _isLoading = false;
    notifyListeners();
  }

  /// Folds the schedule the doctor just saved back in, so the summary under
  /// Set Availability is right the moment they come back rather than after the
  /// next load.
  void applyAvailability(DoctorAvailability availability) {
    _availability = availability;
    _dashboard = _dashboard?.copyWith(isOnline: availability.isOnline);
    notifyListeners();
  }

  /// Picks a photo and uploads it.
  ///
  /// A cancelled picker is not an error and not a state change: the method
  /// returns and nothing on screen moves. Only the upload gets a spinner,
  /// because only the upload takes time the doctor is waiting on.
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
      final path = await _manageProfile.uploadPhoto(picked.localPath);
      // Folded into the dashboard in place rather than re-reading it. The
      // server answered with the path it stored, which is the only field that
      // changed. The path is the same for every photo, so a version is added
      // to it: that is what tells `RemoteAvatar` to fetch the new one.
      _dashboard = _dashboard?.copyWith(photoUrl: _versioned(path));
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
    if (_isSavingPhoto || _dashboard?.photoUrl == null) return;

    _isSavingPhoto = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _manageProfile.removePhoto();
      _dashboard = _dashboard?.copyWith(clearPhoto: true);
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
  /// A failure still signs the doctor out locally — leaving them on a screen
  /// full of their own practice would be the worse outcome.
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

  /// A read whose failure the screen can live without: the row it feeds simply
  /// loses its subtitle instead of taking the whole profile down with it.
  static Future<T?> _quiet<T>(Future<T> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }
}

/// `/patients/me/photo` → `/patients/me/photo?v=1727241600000`. The server
/// ignores the query; the avatar sees a new path and fetches again.
String? _versioned(String? path) =>
    path == null ? null : '$path?v=${DateTime.now().millisecondsSinceEpoch}';
