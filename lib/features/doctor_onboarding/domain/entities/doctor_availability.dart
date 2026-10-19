/// A day of the week, as the availability chips read it.
enum Weekday {
  monday('Mon'),
  tuesday('Tue'),
  wednesday('Wed'),
  thursday('Thu'),
  friday('Fri'),
  saturday('Sat'),
  sunday('Sun');

  const Weekday(this.shortLabel);

  final String shortLabel;

  bool get isWeekend => this == saturday || this == sunday;

  /// Mon-Fri, as the quick pick above the day row offers it.
  static Set<Weekday> get workingWeek =>
      values.where((day) => !day.isWeekend).toSet();

  /// Sat-Sun.
  static Set<Weekday> get weekend =>
      values.where((day) => day.isWeekend).toSet();
}

/// A time of day, kept free of Flutter's `TimeOfDay` so the domain stays
/// framework-agnostic.
class ClockTime implements Comparable<ClockTime> {
  const ClockTime({required this.hour, required this.minute});

  /// 0–23, or 24 for the midnight that **ends** a day.
  ///
  /// The twenty-fourth hour is not a time of day; it is a boundary, and it only
  /// ever appears as the end of a window. Without it there is no way to say "up
  /// to midnight" — 23:59 leaves a minute out, and 00:00 points at the start of
  /// the same day the window began on. The API's `endMinute` allows 1440 for
  /// exactly this reason.
  final int hour;

  /// 0–59.
  final int minute;

  /// The last instant of a day, as the end of a window that runs to midnight.
  static const ClockTime endOfDay = ClockTime(hour: 24, minute: 0);

  static const ClockTime midnight = ClockTime(hour: 0, minute: 0);

  /// True for the midnight that closes a day rather than opens one.
  bool get isEndOfDay => hour >= 24;

  int get minutesSinceMidnight => hour * 60 + minute;

  /// `9:00 AM`
  String get label => isEndOfDay ? '12:00 AM' : '$shortLabel $_meridiem';

  /// `9:00` — the time without its meridiem, for the left half of a range that
  /// already carries one on the right.
  String get shortLabel {
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')}';
  }

  /// `09:00 AM` — for a dropdown, where a fixed width keeps the list tidy.
  String get paddedLabel {
    if (isEndOfDay) return '12:00 AM';

    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')} $_meridiem';
  }

  String get _meridiem => hour < 12 ? 'AM' : 'PM';

  @override
  int compareTo(ClockTime other) =>
      minutesSinceMidnight.compareTo(other.minutesSinceMidnight);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// Which part of the day a window falls in.
///
/// The slot chips are grouped under these rather than run as one undifferen-
/// tiated block: a doctor picking afternoon hours should not have to read
/// eight times to find where the afternoon starts.
enum DayPart {
  morning('Morning'),
  afternoon('Afternoon'),
  evening('Evening');

  const DayPart(this.label);

  final String label;
}

/// A window a doctor is free to consult in.
class AvailabilitySlot {
  const AvailabilitySlot({required this.start, required this.end});

  final ClockTime start;
  final ClockTime end;

  /// `9:00 AM - 10:00 AM`
  String get label => '${start.label} - ${end.label}';

  /// `9:00 - 10:00 AM`, dropping the meridiem from the start when both ends
  /// share one. Two chips only fit across a phone if the label gives up the
  /// repetition; a window that straddles noon keeps both.
  String get compactLabel {
    final sameMeridiem = (start.hour < 12) == (end.hour < 12);
    return sameMeridiem ? '${start.shortLabel} - ${end.label}' : label;
  }

  /// By its start time — a window is a morning one if it begins in the morning.
  DayPart get partOfDay => switch (start.hour) {
    < 12 => DayPart.morning,
    < 17 => DayPart.afternoon,
    _ => DayPart.evening,
  };

  bool get isValid => end.minutesSinceMidnight > start.minutesSinceMidnight;

  /// True when this window runs into [other] — used to keep the day's slots
  /// from double-booking.
  bool overlaps(AvailabilitySlot other) =>
      start.minutesSinceMidnight < other.end.minutesSinceMidnight &&
      other.start.minutesSinceMidnight < end.minutesSinceMidnight;

  @override
  bool operator ==(Object other) =>
      other is AvailabilitySlot && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// The hourly windows the app offers as one-tap choices.
///
/// Lives in the domain because both the backend stub and the chip row have to
/// agree on them — a preset that only one side knows about would show up as a
/// stray custom slot.
abstract final class AvailabilityPresets {
  /// Midnight to midnight. What "available 24/7" is, as a window.
  ///
  /// One slot rather than twenty-four hourly ones: the doctor picked a state,
  /// not a schedule, and a chip row with every hour lit reads as something
  /// they assembled by hand and can take apart the same way.
  static const AvailabilitySlot allDay = AvailabilitySlot(
    start: ClockTime.midnight,
    end: ClockTime.endOfDay,
  );

  static final List<AvailabilitySlot> hourly = List.unmodifiable([
    for (final hour in [9, 10, 11, 13, 14, 15, 16, 17])
      AvailabilitySlot(
        start: ClockTime(hour: hour, minute: 0),
        end: ClockTime(hour: hour + 1, minute: 0),
      ),
  ]);
}

/// When a doctor takes consultations.
class DoctorAvailability {
  const DoctorAvailability({
    this.isOnline = false,
    this.days = const {},
    this.slots = const {},
  });

  /// True when the doctor is taking consultations right now.
  final bool isOnline;

  final Set<Weekday> days;

  /// The windows selected, in no particular order — [sortedSlots] orders them.
  final Set<AvailabilitySlot> slots;

  List<AvailabilitySlot> get sortedSlots =>
      slots.toList()..sort((a, b) => a.start.compareTo(b.start));

  /// True when the doctor consults every day, around the clock.
  ///
  /// Derived rather than stored as a flag of its own. A second source of truth
  /// for "is this doctor always on" is a second thing that can disagree with
  /// the hours — and it is the hours the patient's booking grid is built from,
  /// so the flag would be the one that was wrong.
  bool get isAroundTheClock =>
      days.length == Weekday.values.length &&
      slots.length == 1 &&
      slots.first == AvailabilityPresets.allDay;

  /// The all-day schedule, for the switch that turns it on.
  static DoctorAvailability alwaysOn({bool isOnline = false}) {
    return DoctorAvailability(
      isOnline: isOnline,
      days: Weekday.values.toSet(),
      slots: {AvailabilityPresets.allDay},
    );
  }

  /// `3 selected`
  String get slotCountLabel => '${slots.length} selected';

  /// `3 slots` / `1 slot`.
  String get slotsLabel =>
      '${slots.length} slot${slots.length == 1 ? '' : 's'}';

  /// The days as a person would say them: `Mon-Fri`, `Mon, Wed, Fri`,
  /// `Every day`. Contiguous runs collapse, because a doctor glancing at their
  /// own profile should not have to read seven chips to see they work weekdays.
  String get daysLabel {
    if (days.isEmpty) return 'No days';

    final ordered = Weekday.values.where(days.contains).toList();
    if (ordered.length == Weekday.values.length) return 'Every day';

    final parts = <String>[];
    var runStart = 0;

    for (var i = 0; i < ordered.length; i++) {
      final endsRun =
          i == ordered.length - 1 ||
          ordered[i + 1].index != ordered[i].index + 1;
      if (!endsRun) continue;

      // A run of two reads better spelled out than hyphenated.
      parts.add(switch (i - runStart) {
        0 => ordered[i].shortLabel,
        1 => '${ordered[runStart].shortLabel}, ${ordered[i].shortLabel}',
        _ => '${ordered[runStart].shortLabel}-${ordered[i].shortLabel}',
      });
      runStart = i + 1;
    }

    return parts.join(', ');
  }

  /// `Mon-Fri · 3 slots`, or a prompt when there is nothing set. The subtitle
  /// under Set Availability on the doctor's profile.
  String get summaryLabel {
    if (isAroundTheClock) return 'Available 24/7';
    return isSaveable ? '$daysLabel · $slotsLabel' : 'Not set up yet';
  }

  /// A schedule is only worth saving with at least one day and one window.
  bool get isSaveable => days.isNotEmpty && slots.isNotEmpty;

  /// Why it cannot be saved yet, or null when it can.
  String? get validationError {
    if (days.isEmpty) return 'Pick at least one day.';
    if (slots.isEmpty) return 'Pick at least one time slot.';
    return null;
  }

  DoctorAvailability copyWith({
    bool? isOnline,
    Set<Weekday>? days,
    Set<AvailabilitySlot>? slots,
  }) {
    return DoctorAvailability(
      isOnline: isOnline ?? this.isOnline,
      days: days ?? this.days,
      slots: slots ?? this.slots,
    );
  }
}
