import '../../../../core/format/app_date_format.dart';
import 'doctor_appointment.dart';

/// One day of a doctor's schedule, as the dashboard lists it.
class DoctorAppointmentDay {
  const DoctorAppointmentDay({
    required this.date,
    required this.label,
    required this.appointments,
  });

  /// Midnight on the day, which is what orders the groups.
  final DateTime date;

  /// `Today` / `Tomorrow` / `Mon, 15 Sep`.
  final String label;

  /// That day's consultations, soonest first.
  final List<DoctorAppointment> appointments;
}

/// The day's numbers on the doctor's home screen.
class DoctorDayStats {
  const DoctorDayStats({
    this.consults = 0,
    this.patients = 0,
    this.rating = 0,
    this.earningsToday = 0,
    this.completedTotal = 0,
  });

  /// Consultations completed today.
  final int consults;

  /// Patients seen today.
  final int patients;

  /// Running average out of five.
  final double rating;

  /// What today's completed consultations were billed at, in whole rupees.
  ///
  /// The same figure `GET /doctors/me/earnings?period=today` reports, from the
  /// same rows — carried on the dashboard so the home screen does not need a
  /// second call to tell a doctor what their day is worth.
  final int earningsToday;

  /// Every consultation this doctor has completed, not only today's. What the
  /// home screen sets beside the count still ahead.
  final int completedTotal;

  /// `4.8 ★`, or a plain note before the first rating — an unrated doctor is
  /// not a badly rated one, and `0.0 ★` says the opposite.
  String get ratingLabel =>
      rating == 0 ? '—' : '${rating.toStringAsFixed(1)} ★';

  /// `₹12,600`
  String get earningsLabel => '₹${_grouped(earningsToday)}';

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

/// Everything the doctor home screen renders, fetched in one call.
class DoctorDashboard {
  const DoctorDashboard({
    required this.doctorName,
    required this.speciality,
    this.isOnline = false,
    this.photoUrl,
    this.stats = const DoctorDayStats(),
    this.appointments = const [],
  });

  const DoctorDashboard.empty()
    : doctorName = '',
      speciality = '',
      isOnline = false,
      photoUrl = null,
      stats = const DoctorDayStats(),
      appointments = const [];

  /// Including the title, e.g. `Dr. Amit Verma`.
  final String doctorName;

  final String speciality;

  /// True when the doctor is taking consultations right now. The switch on the
  /// availability screen writes the same flag.
  final bool isOnline;

  /// A path on the API, or null when the doctor has not added a photo — see
  /// `RemoteAvatar`.
  final String? photoUrl;

  final DoctorDayStats stats;

  /// Every consultation still ahead, soonest first — **not** only today's.
  ///
  /// The dashboard used to show the rest of the current day and nothing else,
  /// so a doctor with a clear afternoon and a full Thursday opened the app to
  /// "Nothing booked" and had to go looking for the rest. What is booked is the
  /// question the home screen exists to answer, and the answer does not end at
  /// midnight.
  final List<DoctorAppointment> appointments;

  /// True when anything is still ahead. Asks [appointmentDays] rather than
  /// the raw list, so a diary holding nothing but slots that have already
  /// passed reads as empty — which is what it is.
  bool hasAppointmentsAt({DateTime? now}) =>
      appointmentDays(now: now).isNotEmpty;

  /// The same list, cut into days and labelled — Today, then Tomorrow, then
  /// each date.
  ///
  /// Grouping belongs here rather than in the widget: it is a fact about the
  /// schedule, the order is part of it, and a screen that re-derives it is a
  /// screen that can get it wrong on its own. Pass [now] in a test so the
  /// labels do not depend on when it runs.
  List<DoctorAppointmentDay> appointmentDays({DateTime? now}) {
    final today = now ?? DateTime.now();

    // Sorted here rather than trusted from the wire: the grouping is only
    // meaningful in order, and one row out of sequence would open a second
    // "Today" further down the list.
    //
    // A slot that has been and gone is dropped first. The server holds a
    // booking at `scheduled` until somebody acts on it, so an appointment
    // nobody took stays in the payload — and a 9:00 AM that is now half past
    // eleven sitting at the top of a list headed Upcoming is worse than no
    // list at all: it is the first thing the doctor reads, and it is wrong.
    final sorted =
        [...appointments].where((row) => !row.isOver(now: today)).toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final days = <DateTime, List<DoctorAppointment>>{};
    for (final appointment in sorted) {
      days.putIfAbsent(appointment.day, () => []).add(appointment);
    }

    return [
      for (final entry in days.entries)
        DoctorAppointmentDay(
          date: entry.key,
          label: AppDateFormat.dayLabel(entry.key, now: today),
          appointments: entry.value,
        ),
    ];
  }

  /// `Online` / `Offline` — the label inside the presence dial.
  String get presenceLabel => isOnline ? 'Online' : 'Offline';

  DoctorDashboard copyWith({
    bool? isOnline,
    String? photoUrl,
    bool clearPhoto = false,
  }) {
    return DoctorDashboard(
      doctorName: doctorName,
      speciality: speciality,
      isOnline: isOnline ?? this.isOnline,
      photoUrl: clearPhoto ? null : photoUrl ?? this.photoUrl,
      stats: stats,
      appointments: appointments,
    );
  }
}
