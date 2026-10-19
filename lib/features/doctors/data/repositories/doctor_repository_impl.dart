import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/doctor_repository.dart';
import '../datasources/doctor_remote_data_source.dart';

class DoctorRepositoryImpl implements DoctorRepository {
  const DoctorRepositoryImpl(this._remoteDataSource);

  final DoctorRemoteDataSource _remoteDataSource;

  @override
  Future<List<Doctor>> fetchDoctors({
    String? specialityId,
    bool availableNow = false,
  }) async {
    try {
      return await _remoteDataSource.fetchDoctors(
        specialityId: specialityId,
        availableNow: availableNow,
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }

  @override
  Future<Doctor?> fetchDoctor(String id) async {
    try {
      return await _remoteDataSource.fetchDoctor(id);
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }
}
