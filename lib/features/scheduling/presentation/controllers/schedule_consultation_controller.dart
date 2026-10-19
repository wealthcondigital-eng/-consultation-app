import 'package:flutter/foundation.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/error/failure.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../domain/entities/doctor_schedule.dart';
import '../../domain/entities/schedule_day.dart';
import '../../domain/entities/time_slot.dart';
import '../../domain/usecases/get_doctor_schedule.dart';

/// Presentation state for the schedule consultation screen: which day, which
/// slot, and how the patient wants to take the call.
class ScheduleConsultationController extends ChangeNotifier {
  ScheduleConsultationController(this._getDoctorSchedule);

  final GetDoctorSchedule _getDoctorSchedule;

  DoctorSchedule? _schedule;
  DoctorSchedule? get schedule => _schedule;

  int _dayIndex = 0;

  /// The day the strip has selected. Null until the schedule arrives.
  ScheduleDay? get selectedDay {
    final days = _schedule?.days;
    if (days == null || days.isEmpty) return null;
    return days[_dayIndex.clamp(0, days.length - 1)];
  }

  int get selectedDayIndex => _dayIndex;

  TimeSlot? _slot;
  TimeSlot? get selectedSlot => _slot;

  ConsultationMode _mode = ConsultationMode.video;
  ConsultationMode get mode => _mode;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// A slot has to be picked before there is anything to confirm.
  bool get canConfirm => _slot != null;

  /// `Mon, 18 Aug at 10:30 AM`, or null while nothing is picked.
  String? get appointmentLabel {
    final day = selectedDay;
    final slot = _slot;
    if (day == null || slot == null) return null;
    return tr('{date} at {time}', {
      'date': day.dateLabel,
      'time': slot.timeLabel,
    });
  }

  /// The chosen slot as an actual moment, or null while nothing is picked.
  ///
  /// The label is for reading; this is what gets **booked**. The flow used to
  /// carry only the sentence, which is why the appointment was never filed:
  /// there was nothing in it a server could store.
  ///
  /// Built in local time, because the slot the patient tapped is a time on the
  /// doctor's clock. It is converted to UTC on the wire.
  DateTime? get selectedSlotAt {
    final day = selectedDay;
    final slot = _slot;
    if (day == null || slot == null) return null;

    return DateTime(
      day.date.year,
      day.date.month,
      day.date.day,
      slot.hour,
      slot.minute,
    );
  }

  /// [mode] is what the patient already chose on the way here; they can still
  /// change it on this screen.
  Future<void> load({
    required String doctorId,
    required ConsultationMode mode,

    /// A time the patient already tapped, on the doctor's profile. The grid
    /// opens on that day with that slot selected — arriving on an unselected
    /// grid would throw the choice away and ask it again.
    DateTime? startingAt,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    _mode = mode;
    notifyListeners();

    try {
      _schedule = await _getDoctorSchedule(doctorId: doctorId);
      _dayIndex = _firstDayWithOpenSlots();
      if (startingAt != null) _preselect(startingAt);
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reads the grid again, keeping the patient on the day they were looking at.
  ///
  /// Called when they come back from a booking that did not go through. The
  /// grid on screen was read before the attempt, and if the attempt failed
  /// because somebody else took the slot, that grid is now wrong in exactly
  /// the place the patient is looking: the slot they picked still reads as
  /// free and still reads as selected. So it is fetched again, the day is kept
  /// where it still exists, and the selection is kept only if that slot is
  /// still open — otherwise it is dropped and the Confirm button with it.
  ///
  /// Not [load], which puts the strip back on the first open day. Sending
  /// someone who was choosing a Thursday back to Monday after a failure is a
  /// second thing to recover from.
  Future<void> refresh({required String doctorId}) async {
    if (_isLoading) return;

    final keepDate = selectedDay?.date;
    final keepSlot = _slot;

    _isLoading = true;
    notifyListeners();

    try {
      _schedule = await _getDoctorSchedule(doctorId: doctorId);

      final days = _schedule?.days ?? const [];
      final sameDay = keepDate == null
          ? -1
          : days.indexWhere(
              (day) =>
                  day.date.year == keepDate.year &&
                  day.date.month == keepDate.month &&
                  day.date.day == keepDate.day,
            );

      _dayIndex = sameDay == -1 ? _firstDayWithOpenSlots() : sameDay;

      // Still bookable, or gone. Matched on the clock time rather than by
      // identity: the slots are new objects from a fresh read.
      _slot = keepSlot == null || sameDay == -1
          ? null
          : days[sameDay].slots
                .where(
                  (slot) =>
                      slot.isAvailable &&
                      slot.hour == keepSlot.hour &&
                      slot.minute == keepSlot.minute,
                )
                .firstOrNull;
    } on Failure catch (failure) {
      // The grid already on screen stays. It may be stale, but a blank one
      // after a failed refresh is worse, and the server checks the clash again
      // at booking time whatever this shows.
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selects the day and slot matching [moment], if it is still open.
  ///
  /// Silently does nothing when it is not. Between the profile quoting a time
  /// and the patient tapping it, somebody else can have taken it — and landing
  /// on the right day with nothing selected is a truthful answer to that, where
  /// a selected-but-unbookable slot would not be.
  void _preselect(DateTime moment) {
    final days = _schedule?.days;
    if (days == null) return;

    final dayIndex = days.indexWhere(
      (day) =>
          day.date.year == moment.year &&
          day.date.month == moment.month &&
          day.date.day == moment.day,
    );
    if (dayIndex < 0) return;

    final slot = days[dayIndex].slots.where(
      (slot) =>
          slot.hour == moment.hour &&
          slot.minute == moment.minute &&
          slot.isAvailable,
    );
    if (slot.isEmpty) return;

    _dayIndex = dayIndex;
    _slot = slot.first;
  }

  void selectDay(int index) {
    if (index == _dayIndex) return;

    _dayIndex = index;
    // A slot only means something on the day it was picked from.
    _slot = null;
    notifyListeners();
  }

  void selectSlot(TimeSlot slot) {
    if (!slot.isAvailable || slot == _slot) return;

    _slot = slot;
    notifyListeners();
  }

  void changeMode(ConsultationMode mode) {
    if (mode == _mode) return;

    _mode = mode;
    notifyListeners();
  }

  /// Opens on a day the patient can actually book, rather than on a full one.
  int _firstDayWithOpenSlots() {
    final days = _schedule?.days ?? const [];
    final index = days.indexWhere((day) => day.hasOpenSlots);
    return index == -1 ? 0 : index;
  }
}
