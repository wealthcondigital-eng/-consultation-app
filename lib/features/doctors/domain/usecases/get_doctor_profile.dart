import '../entities/doctor.dart';
import '../repositories/doctor_repository.dart';

/// One doctor in full, for the profile a patient reads before booking.
///
/// Separate from [GetDoctors] because it is a different question with a
/// different cost: the listing returns fifty short rows, and this returns one
/// long one. Folding the profile into the list response would put fifty
/// paragraphs on the wire so that at most one of them could be read.
class GetDoctorProfile {
  const GetDoctorProfile(this._repository);

  final DoctorRepository _repository;

  /// Returns null when there is no such doctor, which the screen shows as the
  /// listing row it already had rather than as an error — the patient is
  /// looking at a doctor that demonstrably exists.
  Future<Doctor?> call(String id) => _repository.fetchDoctor(id);
}
