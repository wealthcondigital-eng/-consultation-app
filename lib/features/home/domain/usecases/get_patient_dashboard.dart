import '../entities/patient_dashboard.dart';
import '../repositories/home_repository.dart';

/// The patient's own numbers, live consultation and recent history.
///
/// Separate from [GetHomeFeed], which is the catalogue. The two are one request
/// each and are fetched together, but they fail independently: a dashboard that
/// could not load must not take the doctor list down with it, because Consult
/// Now still works without it.
class GetPatientDashboard {
  const GetPatientDashboard(this._repository);

  final HomeRepository _repository;

  Future<PatientDashboard> call() => _repository.fetchPatientDashboard();
}
