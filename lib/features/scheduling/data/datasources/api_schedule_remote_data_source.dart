import '../../../../core/network/api_client.dart';
import '../../domain/entities/doctor_schedule.dart';
import '../../domain/entities/schedule_builder.dart';
import '../../domain/entities/schedule_day.dart';
import '../../domain/entities/time_slot.dart';
import 'schedule_remote_data_source.dart';

/// A doctor's bookable slots, from the consultation API.
///
/// **The contract this expects**, for whoever builds the endpoint:
///
/// ```
/// GET /doctors/{doctorId}/schedule?days=7
///
/// {
///   "consultationMinutes": 30,
///   "days": [
///     {
///       "date": "2026-09-14",          // the doctor's local date
///       "isToday": true,
///       "slots": [
///         { "time": "09:00", "available": true  },
///         { "time": "09:30", "available": false }   // already booked
///       ]
///     }
///   ]
/// }
/// ```
///
/// Two things the server owns rather than the app:
///
///  * **`isToday`.** Compared against the server's clock, not the device's, so
///    a phone with the wrong date cannot make tomorrow look bookable today.
///  * **Which slots are taken.** A booked slot comes back `available: false`
///    rather than being left out, because a gap the patient can see is the
///    difference between "the doctor does not work then" and "somebody got
///    there first".
///
/// Days the doctor does not work are simply absent from `days`.
class ApiScheduleRemoteDataSource implements ScheduleRemoteDataSource {
  const ApiScheduleRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  Future<DoctorSchedule> fetchSchedule({required String doctorId}) async {
    final body = await _client.get(
      '/doctors/$doctorId/schedule?days=${ScheduleBuilder.defaultHorizon}',
    );

    final minutes = body['consultationMinutes'];
    final days = body['days'];

    return DoctorSchedule(
      consultationDuration: minutes is num && minutes > 0
          ? Duration(minutes: minutes.toInt())
          : ScheduleBuilder.defaultConsultation,
      days: days is List
          ? days.map(_dayFrom).nonNulls.toList()
          : const <ScheduleDay>[],
    );
  }

  /// Null for a row the app cannot read — a day with no date is not a day, and
  /// dropping it is better than putting an untappable chip on the strip.
  static ScheduleDay? _dayFrom(Object? row) {
    if (row is! Map) return null;

    final date = DateTime.tryParse(row['date'] as String? ?? '')?.toLocal();
    if (date == null) return null;

    final slots = row['slots'];

    return ScheduleDay(
      date: DateTime(date.year, date.month, date.day),
      isToday: row['isToday'] == true,
      slots: slots is List
          ? (slots.map(_slotFrom).nonNulls.toList()..sort(
              (a, b) =>
                  a.minutesSinceMidnight.compareTo(b.minutesSinceMidnight),
            ))
          : const <TimeSlot>[],
    );
  }

  static TimeSlot? _slotFrom(Object? row) {
    if (row is! Map) return null;

    final parts = (row['time'] as String? ?? '').split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return TimeSlot(
      hour: hour,
      minute: minute,
      // Absent means bookable: a server that forgets the flag should not make
      // a doctor's whole day look full.
      isAvailable: row['available'] != false,
    );
  }
}
