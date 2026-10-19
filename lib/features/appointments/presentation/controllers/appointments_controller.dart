import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/format/app_date_format.dart';
import '../../domain/entities/appointment.dart';
import '../../../notifications/domain/usecases/announce_appointments.dart';
import '../../../onboarding/domain/entities/user_role.dart';
import '../../domain/usecases/get_appointments.dart';

/// Presentation state for an appointment list.
///
/// One controller for both roles. [audience] is set once, when the screen
/// creates it, and decides which endpoint is read — everything else about the
/// two lists is identical, which is the point of `Appointment` naming the other
/// party rather than the doctor.
class AppointmentsController extends ChangeNotifier {
  AppointmentsController(
    this._getAppointments,
    this._announceAppointments, {
    required this.audience,
  });

  final GetAppointments _getAppointments;

  /// Turns the list into notifications for whoever is reading it. This is how
  /// the **doctor** finds out a patient booked them: the booking is written on
  /// the patient's phone, and with no push yet the doctor's own appointments
  /// read is the first place their app learns of it.
  final AnnounceAppointments _announceAppointments;

  /// Which end of the consultation this list is being read from.
  final AppointmentAudience audience;

  List<Appointment> _appointments = const [];

  /// Everything the current timeframe returned, before the kind filter.
  List<Appointment> get appointments => _appointments;

  /// Opens on what is ahead rather than on everything.
  ///
  /// A consultation history is long and gets longer; what a patient opens this
  /// screen for is almost always the appointment they have not had yet, and
  /// "All" put that behind a scroll through every call they had ever made.
  AppointmentFilter _filter = AppointmentFilter.upcoming;
  AppointmentFilter get filter => _filter;

  AppointmentKindFilter _kind = AppointmentKindFilter.all;
  AppointmentKindFilter get kind => _kind;

  /// The rows actually shown: the timeframe's rows, narrowed to the chosen
  /// kind and ordered by when they happen.
  ///
  /// Filtered here rather than on the server because the kind is a cheap local
  /// property and switching chips should not cost a round trip — the timeframe
  /// is the expensive axis and is the one the API is asked about.
  List<Appointment> get visibleAppointments {
    final rows = _appointments.where(_kind.matches).toList();

    // Upcoming reads soonest-first (what is next), history reads
    // newest-first (what just happened).
    rows.sort(
      (a, b) => _filter == AppointmentFilter.upcoming
          ? a.occursAt.compareTo(b.occursAt)
          : b.occursAt.compareTo(a.occursAt),
    );

    return rows;
  }

  /// The visible rows cut into days, in the order they are already sorted in —
  /// soonest first on Upcoming, newest first on Past.
  ///
  /// **By day rather than by kind**, which is what this used to be. Instant and
  /// Scheduled is a property of each row, it is already on every card, and the
  /// chips above the list filter on it — so a heading repeating it told the
  /// reader nothing and buried the one thing a list of consultations is read
  /// for, which is when they are. A patient with an appointment on Thursday and
  /// two last week had to read three timestamps to work out which was which.
  ///
  /// [now] is injectable so a test's headings do not depend on the day it runs.
  List<AppointmentGroup> groupsAt({DateTime? now}) {
    final today = now ?? DateTime.now();

    // Insertion-ordered, so the days come out in the order the rows do and the
    // groups need no second sort to agree with the list they came from.
    final days = <DateTime, List<Appointment>>{};

    for (final appointment in visibleAppointments) {
      final at = appointment.occursAt;
      days
          .putIfAbsent(DateTime(at.year, at.month, at.day), () => [])
          .add(appointment);
    }

    return [
      for (final entry in days.entries)
        AppointmentGroup(
          date: entry.key,
          label: AppDateFormat.dayLabel(entry.key, now: today),
          appointments: entry.value,
        ),
    ];
  }

  /// The day groups against the clock now. What the screen renders.
  List<AppointmentGroup> get groups => groupsAt();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;
  bool get isInitialLoad => _isLoading && !_hasLoaded;

  /// True when the list has loaded and there is nothing to show — distinct
  /// from still loading, so the screen shows an empty state rather than a
  /// spinner that never resolves.
  ///
  /// Measured against the **visible** rows, so selecting Scheduled on a list
  /// with only instant consultations says so rather than rendering a blank
  /// scroll view under the chips.
  bool get isEmpty => _hasLoaded && visibleAppointments.isEmpty;

  /// True when the timeframe itself came back empty, as opposed to the kind
  /// filter having hidden everything. The two want different wording: one is
  /// "you have no consultations", the other is "none of these are scheduled".
  bool get isTimeframeEmpty => _hasLoaded && _appointments.isEmpty;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _appointments = await _getAppointments(
        audience: audience,
        filter: _filter,
      );
      _hasLoaded = true;

      // Fire and forget, and idempotent: an appointment already announced is
      // left alone, so re-reading the list does not resurrect a read badge.
      await _announceAppointments(
        appointments: _appointments,
        forRole: audience == AppointmentAudience.doctor
            ? UserRole.doctor
            : UserRole.patient,
      );
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Switches the timeframe and reloads.
  ///
  /// The list is cleared first, so the control never sits above rows belonging
  /// to the tab it just left — a stale list under a new heading is worse than
  /// an empty one for half a second.
  Future<void> setFilter(AppointmentFilter filter) async {
    if (filter == _filter) return;

    _filter = filter;
    _appointments = const [];
    _hasLoaded = false;
    notifyListeners();

    await load();
  }

  /// Switches between instant, scheduled and both.
  ///
  /// No reload: the kind is a property of rows the app already has, and a round
  /// trip to re-ask for a subset of what is in memory is a spinner for nothing.
  void setKind(AppointmentKindFilter kind) {
    if (kind == _kind) return;

    _kind = kind;
    notifyListeners();
  }

  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}

/// One day's consultations, under one heading.
class AppointmentGroup {
  const AppointmentGroup({
    required this.date,
    required this.label,
    required this.appointments,
  });

  /// Midnight on the day these fall on.
  final DateTime date;

  /// `Today` / `Tomorrow` / `21 Sep 2026`.
  final String label;

  final List<Appointment> appointments;
}
