import '../entities/appointment.dart';
import '../repositories/appointment_repository.dart';

/// The consultation history, from whichever end is asking.
class GetAppointments {
  const GetAppointments(this._repository);

  final AppointmentRepository _repository;

  Future<List<Appointment>> call({
    required AppointmentAudience audience,
    AppointmentFilter filter = AppointmentFilter.all,
    int limit = 30,
  }) {
    return _repository.fetchAppointments(
      audience: audience,
      filter: filter,
      limit: limit,
    );
  }
}
