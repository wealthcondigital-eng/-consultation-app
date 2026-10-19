import '../entities/doctor_setup_options.dart';
import '../repositories/doctor_onboarding_repository.dart';

/// Loads the choices the setup form offers.
class GetDoctorSetupOptions {
  const GetDoctorSetupOptions(this._repository);

  final DoctorOnboardingRepository _repository;

  Future<DoctorSetupOptions> call() => _repository.fetchSetupOptions();
}
