import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor_schedule.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../datasources/schedule_remote_data_source.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  const ScheduleRepositoryImpl(this._remoteDataSource);

  final ScheduleRemoteDataSource _remoteDataSource;

  @override
  Future<DoctorSchedule> fetchSchedule({required String doctorId}) async {
    try {
      return await _remoteDataSource.fetchSchedule(doctorId: doctorId);
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }
}
