import '../../../../core/error/failure.dart';
import '../../../../core/logging/auth_logger.dart';
import '../../domain/entities/doctor_schedule.dart';
import 'schedule_remote_data_source.dart';

/// Reads a doctor's real schedule, and falls back to sample hours when the
/// server cannot answer.
///
/// This exists because of a specific gap. A doctor sets their hours on Set
/// Availability and they are saved — to `/doctors/me/availability`, which is
/// **their own** record. There is no endpoint for a *patient* to read another
/// doctor's hours, so the slots a patient is offered have never been the slots
/// the doctor actually chose. A doctor who blocks out Tuesday evenings sees no
/// change on the patient side at all, which is exactly the bug this was written
/// for.
///
/// The app cannot invent that endpoint. What it can do is ask for it and use it
/// the moment it exists: [primary] is tried first, and only a *missing* one
/// falls through to [fallback]. When the backend ships
/// `GET /doctors/{id}/schedule` — see `ApiScheduleRemoteDataSource` for the
/// shape — real availability starts appearing with no change to the app.
///
/// A 404 is the only failure that falls back. A refused session or a dead
/// network are not "this doctor has no schedule", and quietly answering them
/// with invented hours would let a patient book a slot that was never offered.
class ResilientScheduleRemoteDataSource implements ScheduleRemoteDataSource {
  const ResilientScheduleRemoteDataSource({
    required this.primary,
    required this.fallback,
  });

  final ScheduleRemoteDataSource primary;
  final ScheduleRemoteDataSource fallback;

  @override
  Future<DoctorSchedule> fetchSchedule({required String doctorId}) async {
    try {
      return await primary.fetchSchedule(doctorId: doctorId);
    } on Failure catch (failure) {
      if (!failure.isNotFound) rethrow;

      AuthLogger.event('SCHEDULE · no endpoint yet, using sample hours', {
        'doctor': doctorId,
        'needed': 'GET /doctors/{id}/schedule',
      });

      return fallback.fetchSchedule(doctorId: doctorId);
    }
  }
}
