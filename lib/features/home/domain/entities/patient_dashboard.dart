import '../../../appointments/domain/entities/appointment.dart';
import '../../../doctors/domain/entities/speciality.dart';
import '../../../profile/domain/entities/medical_history.dart';

/// The patient's own numbers and state, fetched in one call.
///
/// The counterpart to [DoctorDashboard], and one request for the same reason:
/// this is the screen a patient opens most, and four round trips on a phone
/// connection is four times the wait for one view.
///
/// Deliberately separate from `HomeFeed`, which is the *catalogue* — the
/// specialities and the doctor list. That is the same for everybody and
/// cacheable; this is nobody else's and is not.
class PatientDashboard {
  const PatientDashboard({
    this.patientName = '',
    this.firstName,
    this.photoUrl,
    this.profileComplete = false,
    this.consultations = 0,
    this.doctorsSeen = 0,
    this.spend = 0,
    this.profileCompleteness = 0,
    this.active,
    this.recent = const [],
    this.specialities = const [],
    this.medicalHistory,
  });

  const PatientDashboard.empty()
    : patientName = '',
      firstName = null,
      photoUrl = null,
      profileComplete = false,
      consultations = 0,
      doctorsSeen = 0,
      spend = 0,
      profileCompleteness = 0,
      active = null,
      recent = const [],
      specialities = const [],
      medicalHistory = null;

  final String patientName;

  /// What a greeting calls them. Null until onboarding has a name to use, so
  /// the caller falls back to a generic greeting rather than addressing an
  /// empty string.
  final String? firstName;

  /// A path on the API — see `RemoteAvatar`.
  final String? photoUrl;

  /// False while onboarding is unfinished.
  final bool profileComplete;

  /// Completed consultations, all time.
  final int consultations;

  final int doctorsSeen;

  /// Whole rupees, over completed consultations only. A cancelled call cost
  /// nothing and must not appear as spend.
  final int spend;

  /// How much of the record is filled in, 0-100.
  final int profileCompleteness;

  /// The consultation the patient is in the middle of, if any.
  ///
  /// Its presence is what puts a rejoin banner on the dashboard — a patient who
  /// backgrounded the app mid-call has no other way back in, and the previous
  /// build left them with none.
  final Appointment? active;

  /// The most recent (up to eight), newest first. The first is the "last
  /// consultation" card; the rest feed the doctors under "Consult again".
  final List<Appointment> recent;

  /// The specialities **this patient** has actually consulted, commonest first.
  ///
  /// Empty for a new account, and that is the point. The home screen used to
  /// open on a fixed row of four tiles headed "Popular Specialities" that was
  /// the same for everybody and popular with nobody — a hard-coded list in the
  /// app that no patient's behaviour could change. What somebody has consulted
  /// is a real answer; a new patient has no answer yet, and a section with
  /// nothing honest to put in it should not be drawn.
  final List<Speciality> specialities;

  /// Null when the patient has never recorded anything, which the dashboard
  /// shows as an invitation rather than as four empty lists.
  final MedicalHistory? medicalHistory;

  /// The one consultation the home screen shows as a card: the newest that is
  /// not the [active] one, which already has its own banner.
  Appointment? get lastConsultation {
    for (final appointment in recent) {
      if (appointment.id != active?.id) return appointment;
    }
    return null;
  }

  /// One row per doctor the patient has consulted, newest first — what
  /// "Consult again" offers. Anonymous consultations are left out: linking
  /// them back to a doctor is what anonymity promises not to do.
  List<Appointment> get recentDoctors {
    final seen = <String>{};
    return [
      for (final appointment in recent)
        if (appointment.counterpartId case final id?
            when !appointment.isAnonymous &&
                appointment.status != AppointmentStatus.searching &&
                seen.add(id))
          appointment,
    ];
  }

  /// `Hello, Rahul` / `Hello there`
  String get greeting =>
      firstName == null ? 'Hello there' : 'Hello, $firstName';

  /// `AW` — the avatar's fallback when there is no photo.
  String get initials {
    final parts = patientName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  /// `₹4,200`
  String get spendLabel => '₹${_grouped(spend)}';

  /// True when there is something worth nudging about. Under two-thirds is the
  /// threshold: a patient who has filled in five of six fields does not need a
  /// prompt about the sixth every time they open the app.
  bool get shouldPromptProfile => profileCompleteness < 67;

  /// 0-1, for the completeness ring.
  double get completeness => (profileCompleteness / 100).clamp(0.0, 1.0);

  /// Indian grouping — the first comma after three digits and every two after
  /// that, which is how a rupee amount is read here.
  static String _grouped(int amount) {
    final digits = amount.toString();
    if (digits.length <= 3) return digits;

    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);

    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);

    return '${groups.join(',')},$last3';
  }
}
