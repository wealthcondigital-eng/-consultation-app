import '../../../../core/error/failure.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../datasources/appointment_remote_data_source.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  const AppointmentRepositoryImpl(this._remoteDataSource);

  final AppointmentRemoteDataSource _remoteDataSource;

  @override
  Future<List<Appointment>> fetchAppointments({
    required AppointmentAudience audience,
    required AppointmentFilter filter,
    int limit = 30,
  }) async {
    try {
      return await _remoteDataSource.fetchAppointments(
        audience: audience,
        filter: filter,
        limit: limit,
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }
}
