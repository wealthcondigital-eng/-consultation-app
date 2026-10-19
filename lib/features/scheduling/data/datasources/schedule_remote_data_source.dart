import '../../../doctor_onboarding/domain/entities/doctor_availability.dart';
import '../../domain/entities/doctor_schedule.dart';
import '../../domain/entities/schedule_builder.dart';

/// Supplies a doctor's bookable days and slots.
abstract interface class ScheduleRemoteDataSource {
  Future<DoctorSchedule> fetchSchedule({required String doctorId});
}

/// Sample hours until the scheduling API exists.
///
/// It now *derives* its slots from a weekly availability through
/// [ScheduleBuilder] rather than listing start times by hand. The grid a
/// patient sees is unchanged, and that is the point: the rule that turns hours
/// into slots is the same one the server will run, so when the endpoint lands
/// the only thing that changes is where the availability comes from.
///
/// Two deliberate simplifications, because this is sample data and not a
/// clock-aware server:
///
///  * every doctor keeps the same hours — real ones differ, and
///    [ScheduleBuilder] is tested against evening clinics and weekend-only
///    practices, but a stub that varied by doctor would make what a patient
///    sees depend on which doctor a test happened to pick;
///  * the day starts at midnight rather than now, so today is always on the
///    strip. The real server drops slots that have already passed — the
///    builder does that too, and is tested for it.
class FakeScheduleRemoteDataSource implements ScheduleRemoteDataSource {
  const FakeScheduleRemoteDataSource();

  /// Surgery hours: mornings and early afternoons, seven days a week.
  static final DoctorAvailability _hours = DoctorAvailability(
    isOnline: true,
    days: Weekday.values.toSet(),
    slots: {
      const AvailabilitySlot(
        start: ClockTime(hour: 9, minute: 0),
        end: ClockTime(hour: 11, minute: 0),
      ),
      const AvailabilitySlot(
        start: ClockTime(hour: 14, minute: 0),
        end: ClockTime(hour: 16, minute: 0),
      ),
    },
  );

  /// How far ahead the strip lets a patient book.
  static const bookableDays = 5;

  @override
  Future<DoctorSchedule> fetchSchedule({required String doctorId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final now = DateTime.now();

    return ScheduleBuilder.fromAvailability(
      availability: _hours,
      // From *now*, not from midnight. Anchoring at midnight kept today on the
      // strip whatever the hour, which made the stub tidy and the app wrong:
      // at half past eight in the evening it still offered a 12:30 slot that
      // had gone eight hours earlier, and offered it as bookable.
      from: now,
      horizon: bookableDays,
      booked: _bookedFrom(DateTime(now.year, now.month, now.day)),
    );
  }

  /// One slot taken on each of the first two days, so the grid shows both
  /// states rather than a wall of identical chips.
  static Set<DateTime> _bookedFrom(DateTime from) => {
    for (var offset = 0; offset < 2; offset++)
      DateTime(from.year, from.month, from.day + offset, 9, 30),
  };
}
