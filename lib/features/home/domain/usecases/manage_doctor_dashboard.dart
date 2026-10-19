import '../entities/doctor_dashboard.dart';
import '../repositories/home_repository.dart';

/// The doctor home screen: load it, and change the one thing on it that writes
/// back — whether the doctor is online.
class ManageDoctorDashboard {
  const ManageDoctorDashboard(this._repository);

  final HomeRepository _repository;

  Future<DoctorDashboard> load() => _repository.fetchDoctorDashboard();

  Future<void> setOnline(bool isOnline) =>
      _repository.setDoctorOnline(isOnline);
}
