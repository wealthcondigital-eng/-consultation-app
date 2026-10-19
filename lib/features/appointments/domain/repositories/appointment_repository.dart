import '../entities/appointment.dart';

/// Contract for the appointment lists.
abstract interface class AppointmentRepository {
  /// One consultation history, from whichever end is asking.
  Future<List<Appointment>> fetchAppointments({
    required AppointmentAudience audience,
    required AppointmentFilter filter,
    int limit,
  });
}
