import 'dart:async';

import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/consultation_mode.dart';
import '../../domain/entities/matching_step.dart';
import '../../domain/entities/matching_update.dart';

/// Streams matching progress from the backend.
abstract interface class MatchmakingRemoteDataSource {
  Stream<MatchingUpdate> findDoctor({
    required ConsultationMode mode,
    String? doctorId,
    bool isAnonymous = false,
    String? alias,

    /// What the patient wrote on the way in, carried onto the request so the
    /// doctor can read it while the phone is ringing.
    String? concern,
  });
  Future<Duration> estimatedWait();
}

/// Stand-in until the matching service exists. Swap for a websocket
/// implementation — nothing above this layer changes.
class FakeMatchmakingRemoteDataSource implements MatchmakingRemoteDataSource {
  const FakeMatchmakingRemoteDataSource();

  /// How long each stage takes in the stub.
  static const stepDuration = Duration(milliseconds: 1500);

  static const matchedDoctor = Doctor(
    id: 'amit-verma',
    name: 'Dr. Amit Verma',
    speciality: 'Senior Cardiologist',
    yearsOfExperience: 15,
    rating: 4.9,
    consultationFee: 800,
    audioConsultationFee: 600,
    isVerified: true,
    isAvailableNow: true,
  );

  @override
  Future<Duration> estimatedWait() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
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
    // Driven by a timer rather than awaited delays so that cancelling the
    // subscription really does stop the work — which is what withdrawing from
    // the queue has to do.
    const steps = MatchingStep.values;
    final completed = <MatchingStep>{};
    var index = 0;
    Timer? timer;

    late final StreamController<MatchingUpdate> controller;
    controller = StreamController<MatchingUpdate>(
      onListen: () {
        controller.add(MatchingUpdate(active: steps.first));

        timer = Timer.periodic(stepDuration, (tick) {
          completed.add(steps[index]);
          index++;

          if (index < steps.length) {
            controller.add(
              MatchingUpdate(
                completed: Set.of(completed),
                active: steps[index],
              ),
            );
            return;
          }

          controller.add(
            MatchingUpdate(completed: Set.of(completed), doctor: matchedDoctor),
          );
          tick.cancel();
          controller.close();
        });
      },
      onCancel: () => timer?.cancel(),
    );

    return controller.stream;
  }
}
