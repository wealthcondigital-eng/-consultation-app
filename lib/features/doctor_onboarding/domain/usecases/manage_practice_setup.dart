import '../../../../core/error/failure.dart';
import '../entities/practice_setup.dart';
import '../repositories/doctor_onboarding_repository.dart';

/// The practice wizard: read its state, and set the consultation fees.
class ManagePracticeSetup {
  const ManagePracticeSetup(this._repository);

  final DoctorOnboardingRepository _repository;

  Future<PracticeSetup> load() => _repository.fetchPracticeSetup();

  /// Saves whichever fees are set.
  ///
  /// Throws a [Failure], not an `ArgumentError`. That is the fix for a fee
  /// that would not save with no explanation: the controller catches `Failure`
  /// to get the message and everything else to get the generic one, so an
  /// `ArgumentError` reached the doctor as "Something went wrong" — with the
  /// real reason discarded on the way.
  Future<void> saveFees({int? videoFee, int? audioFee}) {
    if (videoFee == null && audioFee == null) {
      throw const Failure('Set a video or an audio consultation fee.');
    }

    for (final fee in [videoFee, audioFee]) {
      if (fee == null) continue;

      if (fee < PracticeSetup.minFee) {
        throw const Failure('A consultation fee has to be at least ₹1.');
      }
      if (fee > PracticeSetup.maxFee) {
        throw const Failure('That fee is higher than the platform allows.');
      }
    }

    return _repository.saveConsultationFees(
      videoFee: videoFee,
      audioFee: audioFee,
    );
  }
}
