import '../entities/doctor.dart';

/// Contract for browsing doctors.
abstract interface class DoctorRepository {
  /// Every doctor in [specialityId], or all doctors when it is null.
  Future<List<Doctor>> fetchDoctors({String? specialityId, bool availableNow});

  /// One doctor in full, or null when there is no such doctor.
  Future<Doctor?> fetchDoctor(String id);
}
