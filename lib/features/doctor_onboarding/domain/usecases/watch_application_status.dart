import '../entities/doctor_application.dart';
import '../repositories/doctor_onboarding_repository.dart';

/// Follows a submitted registration until the board decides.
class WatchApplicationStatus {
  const WatchApplicationStatus(this._repository);

  final DoctorOnboardingRepository _repository;

  Stream<DoctorApplication> call(String applicationId) =>
      _repository.watchApplication(applicationId);
}
