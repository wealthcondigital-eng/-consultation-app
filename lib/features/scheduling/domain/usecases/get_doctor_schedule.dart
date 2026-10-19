import '../entities/doctor_schedule.dart';
import '../repositories/schedule_repository.dart';

/// Loads the slots a doctor has open.
class GetDoctorSchedule {
  const GetDoctorSchedule(this._repository);

  final ScheduleRepository _repository;

  Future<DoctorSchedule> call({required String doctorId}) =>
      _repository.fetchSchedule(doctorId: doctorId);
}
