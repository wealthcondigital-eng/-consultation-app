import '../entities/doctor_review.dart';
import '../repositories/admin_repository.dart';

/// The review queue.
class GetPendingDoctors {
  const GetPendingDoctors(this._repository);

  final AdminRepository _repository;

  Future<List<DoctorReview>> call() => _repository.fetchPendingDoctors();
}
