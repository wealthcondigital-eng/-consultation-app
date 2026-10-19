import '../../../../core/format/app_date_format.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';

/// Where a booked consultation stands.
enum DoctorAppointmentStatus {
  confirmed('Confirmed'),

  /// The patient is in the waiting room now.
  waiting('Waiting'),

  inProgress('In Progress');

  const DoctorAppointmentStatus(this.label);

  final String label;
}

/// A consultation on the doctor's schedule.
class DoctorAppointment {
  const DoctorAppointment({
    required this.id,
    required this.patientName,
    required this.mode,
    required this.startsAt,
    required this.status,
    this.patientId,
    this.patientPhotoUrl,
    this.isAnonymous = false,
    this.kind = AppointmentKind.instant,
    this.concern,
  });

  /// How early a booking may be opened.
  ///
  /// Matches `ConsultationsService.bookingLeadMs` on the API, which is the copy
  /// that decides: a Start Call button that appears before the server will
  /// accept the join is a button that fails.
  static const Duration joinLead = Duration(minutes: 15);

  final String id;

  /// The patient's name, or their alias on an anonymous booking.
  final String patientName;

  /// Their account id, for the card that opens their history.
  ///
  /// Null on an anonymous consultation — not as an oversight but as the
  /// promise: an id is what joins an alias to the person behind it, and to
  /// every other consultation they have had.
  final String? patientId;

  /// A path on the API for the patient's current photo, or null when they have
  /// not added one. Always null on an anonymous consultation — a face
  /// identifies as surely as a name. See `RemoteAvatar`.
  final String? patientPhotoUrl;

  final ConsultationMode mode;
  final DateTime startsAt;
  final DoctorAppointmentStatus status;

  /// True when the patient booked under an alias — the doctor sees no more
  /// than that.
  final bool isAnonymous;

  /// Instant or scheduled. A booking is not a patient waiting on the line, and
  /// the card says which it is rather than leaving the doctor to work it out
  /// from the time.
  final AppointmentKind kind;

  /// What the patient wrote when they asked.
  ///
  /// The reason the doctor opens the card at all, and on an anonymous
  /// consultation the only thing they are told about the person — before this
  /// was carried they were asked to accept a call from an alias with nothing
  /// else on the sheet.
  final String? concern;

  bool get isScheduled => kind == AppointmentKind.scheduled;

  /// `10:30 AM`
  String get timeLabel => AppDateFormat.clockTime(startsAt);

  /// `Today` / `Tomorrow` / `Mon, 15 Sep` — which day this belongs under.
  ///
  /// Pass [now] in a test so the label does not depend on when it runs.
  String dayLabel({DateTime? now}) =>
      AppDateFormat.dayLabel(startsAt, now: now);

  /// The calendar day this falls on, with the time stripped. What groups a
  /// list into days, and what sorts those groups.
  DateTime get day => DateTime(startsAt.year, startsAt.month, startsAt.day);

  bool isToday({DateTime? now}) =>
      AppDateFormat.isSameDay(startsAt, now ?? DateTime.now());

  /// How long after its start time a booking stays on the schedule.
  ///
  /// One consultation's length, matching `DoctorsService.consultationMinutes`.
  /// The window exists because a doctor who opens the app four minutes late
  /// still has an appointment to take, and dropping the card at the stroke of
  /// the hour would leave them with no way into a call the patient is sitting
  /// in. Once the slot is genuinely over the row is history, and history does
  /// not belong under a heading that says Upcoming.
  static const Duration graceAfterStart = Duration(minutes: 30);

  /// True when this slot has been and gone without being taken.
  ///
  /// Only bookings expire this way. An instant consultation is a person
  /// waiting on the line right now — it has no slot to run out of, and the
  /// server ends it when the patient gives up.
  bool isOver({DateTime? now}) {
    if (!isScheduled) return false;
    if (status == DoctorAppointmentStatus.inProgress) return false;

    return startsAt.add(graceAfterStart).isBefore(now ?? DateTime.now());
  }

  /// `Video Consultation`
  String get modeLabel => mode.label;

  /// True when the doctor can join right now.
  ///
  /// A live call is joinable whenever it is happening. A **booking** becomes
  /// joinable only as its time comes round — [joinLead] before it — because a
  /// confirmed appointment three days out has no room to open, and offering
  /// Start Call on it is offering a call nobody is waiting in.
  ///
  /// The booking case did not exist at all before: every `confirmed` row was
  /// refused, so a doctor with an appointment at three o'clock still had no way
  /// into it at three o'clock.
  bool isJoinable({DateTime? now}) {
    final at = now ?? DateTime.now();

    if (status == DoctorAppointmentStatus.confirmed) {
      return !startsAt.subtract(joinLead).isAfter(at);
    }

    return isToday(now: at);
  }
}
