import 'dart:async';

import '../../domain/entities/consultation_mode.dart';
import '../../domain/entities/live_consultation.dart';
import '../../domain/entities/matching_step.dart';
import '../../domain/entities/matching_update.dart';
import 'consultation_session_remote_data_source.dart';
import 'matchmaking_remote_data_source.dart';

/// Matching, on the consultation API.
///
/// Replaces the timer-driven stub. The three steps the patient watches are no
/// longer a stopwatch — each one is a real state of a real record:
///
/// | Step         | Consultation status        |
/// | ------------ | -------------------------- |
/// | searching    | `searching` — no doctor attached yet
/// | checking     | `ringing`   — one doctor's phone is ringing
/// | connecting   | `accepted`  — they said yes, the channel is being opened
///
/// The stub always finished in four and a half seconds because it was counting;
/// this one finishes when a doctor picks up, and stops when nobody does.
///
/// Cancelling the subscription **withdraws the request**, which is the contract
/// [MatchmakingRemoteDataSource] already stated and the stub could only pretend
/// to honour. Here it is a real `POST /consultations/:id/cancel`, so a patient
/// who backs out stops ringing a doctor rather than leaving one to answer a call
/// nobody is waiting on.
class ApiMatchmakingRemoteDataSource implements MatchmakingRemoteDataSource {
  const ApiMatchmakingRemoteDataSource(this._sessions);

  final ConsultationSessionRemoteDataSource _sessions;

  @override
  Future<Duration> estimatedWait() async {
    // Not served, and a made-up number is better than none here: this drives a
    // countdown the patient reads as "about this long", not a promise. It
    // becomes a real figure when the API can answer how deep the queue is.
    return const Duration(seconds: 45);
  }

  @override
  Stream<MatchingUpdate> findDoctor({
    required ConsultationMode mode,
    String? doctorId,
    bool isAnonymous = false,
    String? alias,
    String? concern,
  }) {
    late final StreamController<MatchingUpdate> controller;
    StreamSubscription<LiveConsultation>? watching;
    String? consultationId;
    var closed = false;
    // Tracked so cancelling the subscription after a doctor answered does not
    // fire a withdrawal at a consultation that is about to become a call.
    var withdrawable = true;

    Future<void> start() async {
      try {
        final consultation = await _sessions.requestInstant(
          mode: mode,
          doctorId: doctorId,
          // The alias travels with the request, and it is the only name the
          // doctor is ever sent. The anonymous flow used to stop at a stub
          // that wrote nothing, so the alias a patient chose reached no API
          // and no doctor was ever rung for it.
          isAnonymous: isAnonymous,
          alias: alias,
          concern: concern,
        );
        if (closed) {
          // The patient left between tapping and the request landing. Withdraw
          // it rather than leaving a doctor to be rung for nobody.
          unawaited(_withdraw(consultation.id));
          return;
        }

        consultationId = consultation.id;
        controller.add(_updateFor(consultation));

        watching = _sessions.watch(consultation.id).listen((update) {
          withdrawable = update.isWaiting;
          controller.add(_updateFor(update));

          // Connected, or never going to be. Either way there is nothing
          // further to report and the screen acts on the last update.
          if (update.isConnectable || update.isOver) {
            controller.close();
          }
        }, onError: controller.addError);
      } catch (error) {
        if (!closed) {
          controller.addError(error);
          await controller.close();
        }
      }
    }

    controller = StreamController<MatchingUpdate>(
      onListen: start,
      onCancel: () async {
        closed = true;
        await watching?.cancel();

        // Only while it is still waiting. A consultation that already connected
        // is ended by hanging up, not withdrawn — and cancelling one that has
        // finished would be a write for nothing.
        final id = consultationId;
        if (id != null && withdrawable) await _withdraw(id);
      },
    );

    return controller.stream;
  }

  Future<void> _withdraw(String id) async {
    try {
      await _sessions.cancel(id);
    } catch (_) {
      // Best effort. The patient has already left the screen, and the API
      // expires an unanswered request on its own — so failing here delays the
      // withdrawal rather than losing it.
    }
  }

  /// One consultation state, as the three-step progress ring reads it.
  static MatchingUpdate _updateFor(LiveConsultation consultation) {
    return switch (consultation.status) {
      // A booking never travels through matching — it is filed against a named
      // doctor at a named time and nobody is rung. Mapped anyway rather than
      // left to a default, so adding a status to the enum keeps failing this
      // switch until somebody decides what the ring should show for it.
      LiveConsultationStatus.scheduled => MatchingUpdate(
        completed: const {MatchingStep.searching, MatchingStep.checking},
        doctor: consultation.doctor,
        consultation: consultation,
      ),
      LiveConsultationStatus.searching => const MatchingUpdate(
        active: MatchingStep.searching,
      ),
      LiveConsultationStatus.ringing => const MatchingUpdate(
        completed: {MatchingStep.searching},
        active: MatchingStep.checking,
      ),
      LiveConsultationStatus.accepted ||
      LiveConsultationStatus.inProgress => MatchingUpdate(
        completed: const {MatchingStep.searching, MatchingStep.checking},
        // The doctor and the consultation together are what the screen needs to
        // open the call: one names who was found, the other names the room.
        doctor: consultation.doctor,
        consultation: consultation,
      ),
      LiveConsultationStatus.completed ||
      LiveConsultationStatus.cancelled ||
      LiveConsultationStatus.expired => MatchingUpdate(
        completed: const {MatchingStep.searching},
        endedReason:
            consultation.endedReason ?? 'The consultation is no longer active.',
      ),
    };
  }
}
