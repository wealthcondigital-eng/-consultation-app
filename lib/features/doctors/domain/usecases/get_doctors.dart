import '../entities/doctor.dart';
import '../repositories/doctor_repository.dart';

/// Loads the doctors shown in a listing.
class GetDoctors {
  const GetDoctors(this._repository);

  final DoctorRepository _repository;

  /// [availableNow] is for the instant flow: a patient asking for a doctor
  /// this minute should not be shown people who cannot answer.
  Future<List<Doctor>> call({
    String? specialityId,
    bool availableNow = false,
  }) => _repository.fetchDoctors(
    specialityId: specialityId,
    availableNow: availableNow,
  );
}
