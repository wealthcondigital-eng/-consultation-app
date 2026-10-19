import '../entities/consultation_mode.dart';
import '../entities/live_consultation.dart';
import '../repositories/consultation_session_repository.dart';

/// Asks for a doctor now, and reports back until one answers.
///
/// Two calls rather than one that does both: filing the request either succeeds
/// or fails outright and the patient should be told immediately, while watching
/// it is a long-lived subscription a screen owns and disposes.
class StartInstantConsultation {
  const StartInstantConsultation(this._repository);

  final ConsultationSessionRepository _repository;

  Future<LiveConsultation> call({
    required ConsultationMode mode,
    String? speciality,
    bool isAnonymous = false,
    String? alias,
    String? concern,
  }) => _repository.requestInstant(
    mode: mode,
    speciality: speciality,
    isAnonymous: isAnonymous,
    alias: alias,
    concern: concern,
  );

  /// Books a slot with a named doctor.
  ///
  /// The missing half of the booking flow: it ended at a confirmation screen
  /// that wrote nothing anywhere, so an appointment existed only as a sentence
  /// the patient had read — no row on the doctor's dashboard, nothing on either
  /// appointment list, and nothing to join when the time came.
  Future<LiveConsultation> schedule({
    required String doctorId,
    required ConsultationMode mode,
    required DateTime scheduledAt,
    String? concern,
    bool isAnonymous = false,
    String? alias,
  }) => _repository.schedule(
    doctorId: doctorId,
    mode: mode,
    scheduledAt: scheduledAt,
    concern: concern,
    isAnonymous: isAnonymous,
    alias: alias,
  );

  Stream<LiveConsultation> watch(String id) => _repository.watch(id);

  /// Withdraws the request. Distinct from dropping the subscription, which only
  /// stops watching — a patient who backs out has to be taken out of the queue,
  /// or a doctor is about to be rung for a call nobody is waiting on.
  Future<LiveConsultation> cancel(String id) => _repository.cancel(id);
}
