import '../entities/consultation_mode.dart';
import '../entities/live_consultation.dart';

/// Contract for brokering an instant consultation between the two people in it.
///
/// Both roles live on one interface because they are two ends of one record:
/// the patient's request and the doctor's answer are edits to the same
/// consultation, and splitting them would hide that.
abstract interface class ConsultationSessionRepository {
  Future<LiveConsultation> requestInstant({
    required ConsultationMode mode,
    String? speciality,
    bool isAnonymous,
    String? alias,
    String? concern,
  });

  /// Books a slot with a named doctor. Nothing is rung — the appointment is the
  /// agreement, and both diaries carry it until its time comes.
  Future<LiveConsultation> schedule({
    required String doctorId,
    required ConsultationMode mode,
    required DateTime scheduledAt,
    String? concern,
    bool isAnonymous,
    String? alias,
  });

  /// Reports the consultation until it connects or ends.
  Stream<LiveConsultation> watch(String id);

  /// Withdraws a request the patient no longer wants. Distinct from letting the
  /// subscription go, which only stops watching.
  Future<LiveConsultation> cancel(String id);

  /// A call ringing for the signed-in doctor, or null when there is none.
  Stream<LiveConsultation?> watchIncoming();

  Future<LiveConsultation> accept(String id);

  Future<LiveConsultation> decline(String id);

  /// Called by both parties as the call screen opens.
  Future<LiveConsultation> join(String id);

  Future<LiveConsultation> end(String id);

  /// [rating] is the doctor, and it is the only figure that feeds their
  /// average. [callQuality] is the connection, which is the platform's fault
  /// rather than theirs — see the field comment on the API's `callQuality`.
  Future<void> rate(
    String id, {
    required int rating,
    String? feedback,
    int? callQuality,
    List<String> tags,
  });
}
