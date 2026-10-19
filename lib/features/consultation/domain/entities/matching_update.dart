import '../../../doctors/domain/entities/doctor.dart';
import 'live_consultation.dart';
import 'matching_step.dart';

/// A snapshot of the matching process, as reported by the backend.
class MatchingUpdate {
  const MatchingUpdate({
    this.completed = const {},
    this.active,
    this.doctor,
    this.consultation,
    this.endedReason,
  });

  /// Steps already finished.
  final Set<MatchingStep> completed;

  /// The step currently running, or null once everything is done.
  final MatchingStep? active;

  /// Set on the final update, once a doctor has accepted.
  final Doctor? doctor;

  /// The consultation the match belongs to, carrying the channel both sides
  /// join. Null on the stub backend, which matches a doctor without there being
  /// a call to open.
  final LiveConsultation? consultation;

  /// Why the search finished without a doctor — nobody available, or the
  /// patient withdrew. Null while it is still running or once it matched.
  final String? endedReason;

  bool get isMatched => doctor != null;

  /// True when the search is over and there is nothing to connect to.
  bool get hasEnded => endedReason != null;

  MatchingStepStatus statusOf(MatchingStep step) {
    if (completed.contains(step)) return MatchingStepStatus.done;
    if (step == active) return MatchingStepStatus.active;
    return MatchingStepStatus.pending;
  }
}
