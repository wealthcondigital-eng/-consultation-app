import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/live_consultation.dart';
import '../../domain/usecases/answer_consultations.dart';

/// The doctor's end of the instant flow: a call arriving, and answering it.
///
/// Lives for as long as the doctor is on their home screen, because the poll
/// behind it is also what tells the API their app is running. A doctor who is
/// marked online but is not being polled stops being offered calls after
/// ninety seconds — which is the point: presence that nobody checks is a
/// promise nobody keeps.
class IncomingConsultationController extends ChangeNotifier {
  IncomingConsultationController(this._answer);

  final AnswerConsultations _answer;

  StreamSubscription<LiveConsultation?>? _subscription;

  LiveConsultation? _incoming;

  /// The call ringing right now, or null when there is none.
  LiveConsultation? get incoming => _incoming;

  bool get hasIncoming => _incoming?.status == LiveConsultationStatus.ringing;

  /// Set once the doctor has accepted and the call is ready to open. The screen
  /// consumes it with [takeAccepted] so it opens the call exactly once.
  LiveConsultation? _accepted;
  LiveConsultation? get accepted => _accepted;

  bool _isAnswering = false;
  bool get isAnswering => _isAnswering;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Starts watching. Safe to call again — a second start is ignored rather
  /// than opening a second poll against the same account.
  void start() {
    if (_subscription != null) return;

    _subscription = _answer.watchIncoming().listen(
      (consultation) {
        // A call the doctor already answered comes back on the next poll as
        // `accepted`. Not shown again as an incoming ring: it is the same call,
        // and re-offering it would put the sheet back over the one they are in.
        _incoming = consultation?.status == LiveConsultationStatus.ringing
            ? consultation
            : null;
        notifyListeners();
      },
      onError: (Object error) {
        // Deliberately quiet. This poll runs continuously in the background, so
        // a blip on the connection must not put an error banner in front of a
        // doctor who is not waiting on anything — the next tick recovers.
        debugPrint('Incoming consultation poll failed: $error');
      },
    );
  }

  Future<void> accept() async {
    final consultation = _incoming;
    if (consultation == null) return;

    await acceptById(consultation.id);
  }

  /// Accepts a consultation by id, whether or not this poll has seen it ring.
  ///
  /// What an Accept on the phone's own ringing screen comes through: the app
  /// may have been killed until a moment ago, so the poll has not run yet and
  /// [incoming] is empty — but the server knows the call is ringing for this
  /// doctor, and that is what decides.
  Future<void> acceptById(String consultationId) async {
    if (_isAnswering) return;

    _isAnswering = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _accepted = await _answer.accept(consultationId);
      if (_incoming?.id == consultationId) _incoming = null;
    } on Failure catch (failure) {
      // The usual cause is a ring that timed out while the doctor reached for
      // the phone — the request has already gone to someone else.
      _errorMessage = failure.message;
      if (_incoming?.id == consultationId) _incoming = null;
    } finally {
      _isAnswering = false;
      notifyListeners();
    }
  }

  Future<void> decline() async {
    final consultation = _incoming;
    if (consultation == null || _isAnswering) return;

    _isAnswering = true;
    notifyListeners();

    try {
      await _answer.decline(consultation.id);
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } finally {
      _incoming = null;
      _isAnswering = false;
      notifyListeners();
    }
  }

  /// Hands over the accepted call, once. The screen opens it and this clears,
  /// so returning from the call does not reopen it.
  LiveConsultation? takeAccepted() {
    final consultation = _accepted;
    _accepted = null;
    return consultation;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
