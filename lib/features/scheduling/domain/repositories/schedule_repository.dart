import '../entities/doctor_schedule.dart';

/// Contract for a doctor's bookable slots.
abstract interface class ScheduleRepository {
  /// Loads the days and slots this doctor is offering.
  Future<DoctorSchedule> fetchSchedule({required String doctorId});
}
