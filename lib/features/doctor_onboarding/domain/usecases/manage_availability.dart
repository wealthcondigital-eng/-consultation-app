import '../../../../core/error/failure.dart';
import '../entities/doctor_availability.dart';
import '../repositories/doctor_onboarding_repository.dart';

/// The doctor's consulting hours: read them, and save a change.
class ManageAvailability {
  const ManageAvailability(this._repository);

  final DoctorOnboardingRepository _repository;

  Future<DoctorAvailability> load() => _repository.fetchAvailability();

  /// Saves the schedule.
  ///
  /// Hours are required only to go **online**. Clearing them while offline is
  /// a legitimate thing to record — it is what the switch is for — and
  /// refusing it here is what left a doctor unable to turn themselves off.
  ///
  /// Throws a [Failure], not an `ArgumentError`. The controller catches
  /// `Failure` for its message and everything else for the generic one, so an
  /// `ArgumentError` reached the doctor as "Something went wrong" with the real
  /// reason discarded on the way.
  Future<void> save(DoctorAvailability availability) {
    if (availability.isOnline) {
      final error = availability.validationError;
      if (error != null) throw Failure(error);
    }

    return _repository.saveAvailability(availability);
  }
}
