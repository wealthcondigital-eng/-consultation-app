import '../../../appointments/domain/entities/appointment.dart';
import '../../../onboarding/domain/entities/user_role.dart';
import 'announce_booking.dart';

/// Raises booking notifications for appointments the app has just read.
///
/// The doctor's half of "tell both of them". A patient books on their own
/// phone, so their confirmation can be written on the spot — but the doctor is
/// on a different device that was not involved, and there is no push yet and no
/// server-side notification table to read from. What the doctor's app *does*
/// have is their own appointments list, and an appointment that appears in it
/// and has never been announced is, from that app's point of view, news.
///
/// So the notification is derived rather than delivered. The limitation is
/// worth stating plainly: the doctor learns about it the next time their app
/// loads appointments, not the instant the patient pays. Closing that gap is
/// what FCM is for, and this is the thing FCM would replace — not a workaround
/// that has to be unpicked first, because the row it writes is the same row a
/// push would arrive as.
///
/// Idempotent, because it runs on every load: `NotificationRepository.raise`
/// keeps an entry that already exists, so a booking read fifty times is
/// announced once and stays read once it has been read.
class AnnounceAppointments {
  const AnnounceAppointments(this._announceBooking);

  final AnnounceBooking _announceBooking;

  /// Announces every booked, still-upcoming appointment in [appointments].
  ///
  /// Never throws: this runs behind a list that has already loaded, and a
  /// notification that could not be written must not blank the screen showing
  /// the appointments themselves.
  Future<void> call({
    required List<Appointment> appointments,
    required UserRole forRole,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();

    for (final appointment in appointments) {
      // Only bookings. An instant consultation was not scheduled, so there is
      // no "booked for Thursday" to tell anybody about.
      if (appointment.kind != AppointmentKind.scheduled) continue;

      final startsAt = appointment.scheduledAt;
      if (startsAt == null) continue;

      // Nothing to announce about an appointment that has already happened —
      // and nothing to remind anyone of either.
      if (!startsAt.isAfter(clock)) continue;

      await _announceBooking(
        consultationId: appointment.id,
        counterpartName: appointment.counterpartName,
        startsAt: startsAt,
        scheduledFor: appointment.whenLabel,
        forRole: forRole,
      );
    }
  }
}
