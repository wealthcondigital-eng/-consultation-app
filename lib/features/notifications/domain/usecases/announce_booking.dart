import '../../../onboarding/domain/entities/user_role.dart';
import '../entities/app_notification.dart';
import '../repositories/notification_repository.dart';

/// Writes everything a booked consultation has to say: the confirmation now,
/// and a reminder at each of [consultationReminderLeads] before it starts.
///
/// All of them are written **at booking time**, which is the whole design. The
/// reminders are not timers the app sets — a timer dies with the process, and
/// the app is not running at 20:00 on a Thursday for a 20:30 appointment. Each
/// is a row with a time on it, so it arrives whether or not anything was
/// watching, and they are the same rows a push notification will be sent from
/// once the server owns this.
///
/// **The copy depends on who is reading it.** The same appointment is "you
/// booked this" to a patient and "somebody booked you" to a doctor, and a
/// doctor told to have their prescriptions ready is being given the patient's
/// instructions. [forRole] picks the wording; everything else is shared.
///
/// Never throws. A booking that succeeded must not be reported as failed
/// because the confirmation could not be filed — the appointment exists either
/// way, and it is on the appointments list.
class AnnounceBooking {
  const AnnounceBooking(this._repository);

  final NotificationRepository _repository;

  Future<void> call({
    required String consultationId,
    required DateTime startsAt,
    required String scheduledFor,

    /// The other person: the doctor's name to a patient, the patient's to a
    /// doctor.
    required String counterpartName,

    /// Whose notifications these are. Defaults to the patient, who is the one
    /// doing the booking.
    UserRole forRole = UserRole.patient,
  }) async {
    final now = DateTime.now();
    final isDoctor = forRole == UserRole.doctor;

    try {
      await _repository.raise([
        AppNotification(
          id: 'booking-$consultationId',
          kind: NotificationKind.bookingConfirmed,
          title: isDoctor ? 'New appointment booked' : 'Consultation booked',
          body: isDoctor
              // The doctor did not do this; somebody did it to their diary.
              ? '$counterpartName booked you for $scheduledFor. '
                    'It is on your appointments list.'
              : '$counterpartName · $scheduledFor. '
                    'You will get a reminder shortly before it starts.',
          createdAt: now,
          consultationId: consultationId,
          startsAt: startsAt,
        ),
        for (final lead in consultationReminderLeads)
          _reminder(
            consultationId: consultationId,
            counterpartName: counterpartName,
            startsAt: startsAt,
            lead: lead,
            isDoctor: isDoctor,
            now: now,
          ),
      ]);
    } catch (_) {
      // Nothing to say and nothing to undo.
    }
  }

  /// One reminder, worded for how close the consultation is.
  ///
  /// The distance is the message. "Starts soon" four times over is noise people
  /// learn to swipe away; naming what to do with the time left is what makes
  /// the fourth one still worth reading.
  static AppNotification _reminder({
    required String consultationId,
    required String counterpartName,
    required DateTime startsAt,
    required Duration lead,
    required bool isDoctor,
    required DateTime now,
  }) {
    final minutes = lead.inMinutes;

    final advice = switch (minutes) {
      // Far enough out to finish what you are doing rather than drop it.
      >= 30 =>
        isDoctor
            ? 'Their notes and history are on the consultation.'
            : 'Finish what you are on and keep your reports nearby.',
      // The preparation window.
      >= 15 =>
        isDoctor
            ? 'A good moment to read their concern before you join.'
            : 'Find somewhere quiet and keep any reports, prescriptions or '
                  'test results to hand.',
      // Stop and go.
      >= 5 => 'Time to head to the call.',
      // The room is open by now.
      _ => 'You can join now.',
    };

    return AppNotification(
      // Keyed by lead as well as consultation, or the four would collide on one
      // id and only the first would ever be written.
      id: 'reminder-$minutes-$consultationId',
      kind: NotificationKind.consultationReminder,
      title: minutes <= 2
          ? 'Your consultation is starting'
          : 'Consultation in $minutes minutes',
      body: '$counterpartName · $advice',
      createdAt: now,
      showAfter: startsAt.subtract(lead),
      consultationId: consultationId,
      startsAt: startsAt,
    );
  }
}
