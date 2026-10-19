import '../entities/consultation_mode.dart';
import '../entities/matching_update.dart';

/// Contract for pairing a patient with an available doctor.
abstract interface class MatchmakingRepository {
  /// Reports progress until a doctor accepts, then completes.
  ///
  /// Cancelling the subscription withdraws the request.
  Stream<MatchingUpdate> findDoctor({
    required ConsultationMode mode,
    String? doctorId,
    bool isAnonymous = false,
    String? alias,
    String? concern,
  });

  /// How long the queue is expected to take right now.
  Future<Duration> estimatedWait();
}
