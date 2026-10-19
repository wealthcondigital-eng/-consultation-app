import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor.dart';
import '../../../scheduling/domain/entities/doctor_schedule.dart';
import '../../../scheduling/domain/usecases/get_doctor_schedule.dart';
import '../../domain/usecases/get_doctor_profile.dart';

/// Presentation state for one doctor's profile.
///
/// Seeded with the row the listing already had, so the screen opens with the
/// name, the speciality and the fee on it and fills in the description behind
/// them. A profile that spends a second as a spinner is a profile people back
/// out of before it arrives — and everything they need to *recognise* the
/// doctor is already in hand.
class DoctorDetailController extends ChangeNotifier {
  DoctorDetailController(
    this._getProfile,
    this._getSchedule, {
    required Doctor initial,
  }) : _doctor = initial;

  final GetDoctorProfile _getProfile;

  /// When this doctor is next free. Read here rather than only on the booking
  /// screen: "when can I see you" is the question an offline doctor's profile
  /// exists to answer, and the answer used to be two taps and a grid away.
  final GetDoctorSchedule _getSchedule;

  Doctor _doctor;
  Doctor get doctor => _doctor;

  bool _isLoading = false;

  /// True while the long form is still coming. The screen dims the About
  /// section rather than replacing the whole page.
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  String? _errorMessage;

  /// Set only when the profile read failed outright.
  ///
  /// Not fatal: the seed row is still on screen and still bookable, so this is
  /// an inline note rather than an error page. A patient who can see the doctor
  /// and the fee should not be stopped from calling them because a paragraph
  /// did not load.
  String? get errorMessage => _errorMessage;

  DoctorSchedule? _schedule;

  /// Null until the schedule arrives, and null for good if it could not be
  /// read. The profile carries on without it — a patient who can see the doctor
  /// and the fee is not stopped from calling them because a grid did not load.
  DoctorSchedule? get schedule => _schedule;

  /// The soonest few times this doctor is free, for the profile to quote.
  List<OpenSlot> get nextOpenSlots => _schedule?.nextOpen() ?? const [];

  /// True once the schedule read finished and found nothing bookable — which
  /// is a different thing from not having asked yet, and says so on screen.
  bool get hasNoOpenSlots => _schedule != null && !_schedule!.hasOpenSlots;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Side by side: neither answer depends on the other, and run in turn they
    // would add a round trip to a screen that is already open and waiting.
    final profileRead = _getProfile(_doctor.id);
    final scheduleRead = _loadSchedule();

    try {
      final profile = await profileRead;
      // Merged rather than replaced: a profile response that omits a field
      // must not blank what the listing already showed.
      if (profile != null) _doctor = _doctor.mergedWith(profile);
      _hasLoaded = true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      await scheduleRead;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Never throws. A schedule that could not be read leaves the section off the
  /// profile rather than putting an error on a page that is otherwise fine.
  Future<void> _loadSchedule() async {
    try {
      _schedule = await _getSchedule(doctorId: _doctor.id);
    } catch (_) {
      _schedule = null;
    }
  }

  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
