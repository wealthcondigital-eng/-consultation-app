import '../entities/live_consultation.dart';
import '../repositories/consultation_session_repository.dart';

/// The doctor's side of an instant consultation.
///
/// Watching is also what tells the API the doctor's app is alive, so this runs
/// for as long as they are on shift rather than only while a particular screen
/// is open — a doctor who is online and not being polled is a doctor matching
/// will stop offering calls to.
class AnswerConsultations {
  const AnswerConsultations(this._repository);

  final ConsultationSessionRepository _repository;

  /// Emits the call ringing for this doctor, or null when there is none.
  Stream<LiveConsultation?> watchIncoming() => _repository.watchIncoming();

  Future<LiveConsultation> accept(String id) => _repository.accept(id);

  /// Turning it down puts the request back in the queue for another doctor —
  /// the patient asked for *a* doctor, not this one.
  Future<LiveConsultation> decline(String id) => _repository.decline(id);
}

/// Opening and closing the room. Used by both parties, which is why it is not
/// on either side's use case.
class ManageConsultationCall {
  const ManageConsultationCall(this._repository);

  final ConsultationSessionRepository _repository;

  /// Called as the call screen opens. Idempotent, and the first of the two
  /// callers is what marks the consultation as actually under way.
  Future<LiveConsultation> join(String id) => _repository.join(id);

  Future<LiveConsultation> end(String id) => _repository.end(id);

  /// Withdraws a request the patient no longer wants.
  ///
  /// Distinct from [end], which closes a call that happened, and from dropping
  /// the watch, which only stops looking. The request lives on the server, so
  /// leaving the screen — or the app — does not stop it: a patient who backed
  /// out of the search came back to the same "Finding a doctor" card and, worse,
  /// could still be rung by a doctor accepting it. This is the way to actually
  /// call it off.
  Future<LiveConsultation> cancel(String id) => _repository.cancel(id);

  /// The patient's review of a consultation that has finished.
  ///
  /// [rating] is the doctor and is the only figure that moves their average.
  /// [callQuality] is the connection, which is ours rather than theirs.
  Future<void> rate(
    String id, {
    required int rating,
    String? feedback,
    int? callQuality,
    List<String> tags = const [],
  }) => _repository.rate(
    id,
    rating: rating,
    feedback: feedback,
    callQuality: callQuality,
    tags: tags,
  );
}
