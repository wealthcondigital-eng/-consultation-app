/// Half of the day a slot falls in. The heading above a group of slots says
/// which, so the times themselves need no am/pm.
enum SlotPeriod {
  morning('Morning Slots'),
  afternoon('Afternoon Slots'),

  /// Doctors offer evening hours and many of them only offer evening hours —
  /// before this existed those windows were filed under "afternoon", so a
  /// clinic running 6–9pm appeared to start its afternoon after dark.
  evening('Evening Slots');

  const SlotPeriod(this.label);

  final String label;
}

/// One bookable start time on a doctor's day.
class TimeSlot {
  const TimeSlot({
    required this.hour,
    required this.minute,
    this.isAvailable = true,
  });

  /// On a 24-hour clock, so morning and afternoon slots sort naturally.
  final int hour;
  final int minute;

  /// False when the slot is already taken. It stays on the grid, greyed out,
  /// rather than disappearing — a gap in the day is information too.
  final bool isAvailable;

  /// Sorts the day's slots, and the value a window's bounds are compared in.
  int get minutesSinceMidnight => hour * 60 + minute;

  /// The same boundaries `AvailabilitySlot.partOfDay` uses, so a window the
  /// doctor filed under Evening does not come back to the patient as an
  /// afternoon one.
  SlotPeriod get period => switch (hour) {
    < 12 => SlotPeriod.morning,
    < 17 => SlotPeriod.afternoon,
    _ => SlotPeriod.evening,
  };

  String get _meridiem => hour < 12 ? 'AM' : 'PM';

  int get _hour12 => hour % 12 == 0 ? 12 : hour % 12;

  /// `09:00`, `02:30` — as shown on the grid, under its period heading.
  String get label =>
      '${_hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// `02:30 PM` — for anywhere the slot appears without its heading.
  String get timeLabel => '$label $_meridiem';

  @override
  bool operator ==(Object other) =>
      other is TimeSlot && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}
