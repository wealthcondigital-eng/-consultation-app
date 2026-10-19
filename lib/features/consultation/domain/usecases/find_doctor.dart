import '../entities/consultation_mode.dart';
import '../entities/matching_update.dart';
import '../repositories/matchmaking_repository.dart';

/// Pairs the patient with an available doctor, reporting progress.
class FindDoctor {
  const FindDoctor(this._repository);

  final MatchmakingRepository _repository;

  /// [doctorId] binds the request to one doctor — the patient tapped a name off
  /// a listing, and ringing somebody else instead is not a smaller version of
  /// what they asked for. Null means anyone available.
  /// [alias] is the only name the doctor is sent when [isAnonymous] is true.
  /// An anonymous consultation is an ordinary one with a different name on it —
  /// there is no separate flow, and there used not to be a real one at all.
  /// [concern] is what the patient typed before asking. It goes onto the
  /// request so the doctor reads it while deciding whether to answer — on an
  /// anonymous consultation it is the only thing they know about the caller.
  Stream<MatchingUpdate> call({
    required ConsultationMode mode,
    String? doctorId,
    bool isAnonymous = false,
    String? alias,
    String? concern,
  }) => _repository.findDoctor(
    mode: mode,
    doctorId: doctorId,
    isAnonymous: isAnonymous,
    alias: alias,
    concern: concern,
  );

  Future<Duration> estimatedWait() => _repository.estimatedWait();
}
