import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor_availability.dart';
import '../../domain/usecases/manage_availability.dart';

/// Presentation state for Set Availability.
class AvailabilityController extends ChangeNotifier {
  AvailabilityController(this._manageAvailability);

  final ManageAvailability _manageAvailability;

  /// The one-tap windows, shared with the backend so the chip row and the
  /// stored slots cannot drift apart.
  List<AvailabilitySlot> get presetSlots => AvailabilityPresets.hourly;

  DoctorAvailability _availability = const DoctorAvailability();
  DoctorAvailability get availability => _availability;

  /// Windows the doctor added by hand, shown after the presets.
  final List<AvailabilitySlot> _customSlots = [];
  List<AvailabilitySlot> get customSlots => List.unmodifiable(_customSlots);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;
  bool get isInitialLoad => _isLoading && !_hasLoaded;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// True when there is a schedule worth sending.
  ///
  /// Not `isSaveable`, which was the bug: that requires a day *and* a window,
  /// so a doctor going offline — clearing their hours, which is the whole
  /// point of the switch — found Save permanently disabled and no way to
  /// record it. Hours are only required to go **online**; an offline schedule
  /// is allowed to be empty, and the API agrees.
  bool get canSave =>
      !_isSaving && (!_availability.isOnline || _availability.isSaveable);

  /// Why Save is off, or null when it is on. What the bar under it prints.
  String? get blockedReason {
    if (!_availability.isOnline) return null;
    return _availability.validationError;
  }

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _availability = await _manageAvailability.load();
      // A stored slot that is not one of the presets was added by hand, so it
      // needs a chip of its own.
      _customSlots
        ..clear()
        ..addAll(
          _availability.sortedSlots.where(
            (slot) => !presetSlots.contains(slot),
          ),
        );
      _hasLoaded = true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleOnline(bool isOnline) {
    _availability = _availability.copyWith(isOnline: isOnline);
    notifyListeners();
  }

  /// Turns the whole week on, midnight to midnight, or takes it off again.
  ///
  /// Turning it **off** clears the hours rather than restoring whatever was
  /// selected before: the previous schedule was replaced when the switch went
  /// on, and resurrecting it would put a doctor back on hours they may have
  /// chosen months ago without being shown them. An empty schedule is a
  /// deliberate, saveable state — see [canSave].
  void setAroundTheClock(bool isAlways) {
    _availability = isAlways
        ? DoctorAvailability.alwaysOn(isOnline: _availability.isOnline)
        : _availability.copyWith(
            days: const <Weekday>{},
            slots: const <AvailabilitySlot>{},
          );

    notifyListeners();
  }

  void toggleDay(Weekday day) {
    final days = Set<Weekday>.of(_availability.days);
    days.contains(day) ? days.remove(day) : days.add(day);

    _availability = _availability.copyWith(days: days);
    notifyListeners();
  }

  /// Replaces the whole day selection — what the quick picks above the day row
  /// do. Picking the set that is already chosen clears it, so the same tap
  /// undoes itself.
  void selectDays(Set<Weekday> days) {
    final isAlreadyChosen =
        days.length == _availability.days.length &&
        _availability.days.containsAll(days);

    _availability = _availability.copyWith(
      days: isAlreadyChosen ? const <Weekday>{} : Set<Weekday>.of(days),
    );
    notifyListeners();
  }

  void toggleSlot(AvailabilitySlot slot) {
    final slots = Set<AvailabilitySlot>.of(_availability.slots);
    slots.contains(slot) ? slots.remove(slot) : slots.add(slot);

    _availability = _availability.copyWith(slots: slots);
    notifyListeners();
  }

  /// Adds a window the doctor entered themselves, and selects it.
  ///
  /// Returns false with an explanation when the window makes no sense or is
  /// already covered.
  bool addCustomSlot(AvailabilitySlot slot) {
    if (!slot.isValid) {
      _errorMessage = 'The end time has to be after the start time.';
      notifyListeners();
      return false;
    }

    final existing = [...presetSlots, ..._customSlots];
    if (existing.contains(slot)) {
      _errorMessage = 'That time slot is already listed.';
      notifyListeners();
      return false;
    }

    _customSlots.add(slot);
    toggleSlot(slot);
    return true;
  }

  /// Takes a hand-entered window off the list for good.
  ///
  /// Presets have no equivalent: they are the platform's, and a doctor who does
  /// not want one simply leaves it unselected. A custom window is the doctor's
  /// own, and one added by mistake had nowhere to go — deselecting left it
  /// sitting in the list forever.
  void removeCustomSlot(AvailabilitySlot slot) {
    if (!_customSlots.remove(slot)) return;

    final slots = Set<AvailabilitySlot>.of(_availability.slots)..remove(slot);
    _availability = _availability.copyWith(slots: slots);
    notifyListeners();
  }

  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Saves the schedule. Returns true when the doctor can move on.
  Future<bool> save() async {
    if (_isSaving) return false;

    // Only checked for a doctor going online. Clearing your hours is a
    // legitimate thing to save, and refusing it here is what left the switch
    // with no way to be turned off.
    if (_availability.isOnline) {
      final error = _availability.validationError;
      if (error != null) {
        _errorMessage = error;
        notifyListeners();
        return false;
      }
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _manageAvailability.save(_availability);
      return true;
    } on Failure catch (failure) {
      // The API refuses `isOnline: true` from a doctor whose registration is
      // not approved — and *keeps the hours it was sent*. Reflecting that
      // rather than only reporting it: the schedule is stored, the switch was
      // not, and leaving the switch on would show a state the server does not
      // hold. The message says both, so the doctor is not left guessing which
      // half took.
      if (_availability.isOnline) {
        _availability = _availability.copyWith(isOnline: false);
      }
      _errorMessage = failure.message;
      return false;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
