import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/consultation_mode.dart';
import '../../domain/entities/live_consultation.dart';
import '../../domain/entities/matching_update.dart';
import '../../domain/usecases/find_doctor.dart';

/// Presentation state for the "finding you a doctor" screen.
///
/// Two clocks run here on purpose: the step progress comes from the backend
/// stream, while the countdown is a local display of the queue estimate.
class DoctorMatchingController extends ChangeNotifier {
  DoctorMatchingController(this._findDoctor);

  final FindDoctor _findDoctor;

  StreamSubscription<MatchingUpdate>? _subscription;
  Timer? _countdown;

  MatchingUpdate _update = const MatchingUpdate();
  MatchingUpdate get update => _update;

  Duration _remaining = Duration.zero;

  /// `00:45`
  String get remainingLabel {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  Doctor? get matchedDoctor => _update.doctor;
  bool get isMatched => _update.isMatched;

  /// The consultation the match belongs to — the channel both sides join, and
  /// which of the two this device is inside it. Null on the stub backend, where
  /// a doctor is matched but there is no call to open.
  LiveConsultation? get matchedConsultation => _update.consultation;

  /// Set when the search finished with no doctor: nobody was available, or the
  /// patient's own withdrawal came back. The screen shows this instead of
  /// spinning on a search that is over.
  String? get endedReason => _update.endedReason;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Files the request and watches it until a doctor answers.
  ///
  /// [alias] is set for an anonymous consultation and is the only name the
  /// doctor is sent. It goes on the same request as everything else: there is
  /// no separate anonymous path, which is exactly why the old one — a stub that
  /// returned a local id and rang nobody — could look like it worked.
  /// [concern] is what the patient wrote before asking. It travels on the
  /// request so the doctor can read it while their phone is ringing — on an
  /// anonymous consultation it is the only thing they know about the caller.
  Future<void> start(
    ConsultationMode mode, {
    String? doctorId,
    String? alias,
    String? concern,
  }) async {
    if (_isSearching || isMatched) return;

    _isSearching = true;
    _errorMessage = null;
    notifyListeners();

    _remaining = await _findDoctor.estimatedWait();
    _startCountdown();

    _subscription =
        _findDoctor(
          mode: mode,
          doctorId: doctorId,
          isAnonymous: alias != null,
          alias: alias,
          concern: concern,
        ).listen(
          (update) {
            _update = update;
            // A match and a search that ran out both end the wait. Stopping on the
            // second is what turns "nobody was available" into a screen the patient
            // can act on rather than a ring that spins forever.
            if (update.isMatched || update.hasEnded) _stopClocks();
            notifyListeners();
          },
          onError: (Object error) {
            _errorMessage = error is Failure
                ? error.message
                : const Failure.unexpected().message;
            _stopClocks();
            notifyListeners();
          },
          onDone: () {
            _isSearching = false;
            notifyListeners();
          },
        );
  }

  /// Withdraws the request. The stream subscription is what holds the patient's
  /// place in the queue, so cancelling it is the cancellation.
  void cancel() {
    _stopClocks();
    notifyListeners();
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds <= 0) {
        timer.cancel();
        return;
      }
      _remaining -= const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _stopClocks() {
    _isSearching = false;
    _countdown?.cancel();
    _countdown = null;
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    _stopClocks();
    super.dispose();
  }
}
