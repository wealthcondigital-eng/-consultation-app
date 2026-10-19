import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor_dashboard.dart';
import '../../domain/entities/home_feed.dart';
import '../../domain/entities/patient_dashboard.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_data_source.dart';

class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl(this._remoteDataSource);

  final HomeRemoteDataSource _remoteDataSource;

  @override
  Future<HomeFeed> fetchHomeFeed() async {
    try {
      return await _remoteDataSource.fetchHomeFeed();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }

  @override
  Future<PatientDashboard> fetchPatientDashboard() async {
    try {
      return await _remoteDataSource.fetchPatientDashboard();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }

  @override
  Future<DoctorDashboard> fetchDoctorDashboard() async {
    try {
      return await _remoteDataSource.fetchDoctorDashboard();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }

  @override
  Future<void> setDoctorOnline(bool isOnline) async {
    try {
      await _remoteDataSource.setDoctorOnline(isOnline);
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }
}
