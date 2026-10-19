import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/l10n/tr.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/entities/speciality.dart';
import '../../../doctors/domain/usecases/get_doctors.dart';
import '../../domain/entities/matching_step.dart';
import '../../domain/entities/matching_update.dart';
import '../../domain/usecases/find_doctor.dart';

/// Where one search for a doctor has got to.
enum DoctorSearchPhase {
  /// Nothing has been asked for. Nothing is shown anywhere.
  idle,

  /// Running. The dashboard shows a spinner and the search screen the ring.
  searching,

  /// Finished with at least one doctor. The dashboard offers them.
  found,

  /// Finished with nobody online.
  empty,

  /// The search itself failed — no connection, or the API refused.
  failed,
}

/// A search for a doctor that **outlives the screen that started it**.
///
/// The gap this closes: tapping Instant Consultation opened a full-screen
/// search, and backing out of it threw the search away. A patient who pressed
/// back — to check something, or by reflex, or because a progress ring looked
/// like it had nothing more to say — returned to a dashboard that mentioned
/// none of it, and had to start again from the Consult Now card.
///
/// So the search does not live on the screen any more. It lives here, as one
/// object for the whole app, and the screen is a *view* of it: leaving the
/// screen puts the search in the background, where the dashboard reports it as
/// a card. Tapping the card opens the doctors it found.
///
/// **A singleton, deliberately.** Two of these would be two searches, and the
/// dashboard would report whichever one it happened to hold — so it is
/// registered with `registerLazySingleton` and never disposed. [clear] is how a
/// finished search goes away, not `dispose`.
///
/// This is **discovery**, not a consultation: it asks who is online and files
/// nothing. Nobody is rung, so leaving it running costs a doctor nothing —
/// which is exactly what makes backgrounding it safe, and is why a *request*
/// for a doctor (`DoctorMatchingController.start`) must still be withdrawn when
/// the patient gives up on it.
class DoctorSearchSession extends ChangeNotifier {
  DoctorSearchSession(this._getDoctors, this._findDoctor);

  final GetDoctors _getDoctors;

  /// Only for the queue estimate the ring counts down. The search itself does
  /// not go through matching — see the class comment.
  final FindDoctor _findDoctor;

  /// A real search finishes in a few hundred milliseconds, and a progress ring
  /// that vanishes before it has been read looks like a glitch rather than a
  /// search. Held just long enough to be legible.
  static const Duration settleDelay = Duration(milliseconds: 900);

  DoctorSearchPhase _phase = DoctorSearchPhase.idle;
  DoctorSearchPhase get phase => _phase;

  MatchingUpdate _update = const MatchingUpdate();
  MatchingUpdate get update => _update;

  /// What was asked for, so the card and the listing it opens agree.
  Speciality? _speciality;
  Speciality? get speciality => _speciality;

  bool _instantOnly = false;

  /// True when the search was opened from Instant Consultation, which is what
  /// makes the listing show only doctors who can answer this minute.
  bool get instantOnly => _instantOnly;

  List<Doctor> _results = const [];
  List<Doctor> get results => _results;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _countdown;
  Duration _remaining = Duration.zero;

  /// Which search is the current one.
  ///
  /// Bumped on every [start] and on [clear], and checked after every await: a
  /// search the patient has replaced or dismissed must not write its answer
  /// back over the one they are actually waiting on.
  int _run = 0;

  bool get isSearching => _phase == DoctorSearchPhase.searching;

  /// True when there is anything for the dashboard to show — a search running,
  /// or one whose answer the patient has not looked at yet.
  bool get isActive => _phase != DoctorSearchPhase.idle;

  /// `00:45` — the queue estimate, counted down while the search runs.
  String get remainingLabel {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// `3 doctors found` — what the dashboard card says.
  String get headline => switch (_phase) {
    DoctorSearchPhase.searching => tr('Finding a doctor'),
    DoctorSearchPhase.found =>
      _results.length == 1
          ? tr('1 doctor found')
          : tr('{count} doctors found', {'count': _results.length}),
    DoctorSearchPhase.empty => tr('No doctors available'),
    DoctorSearchPhase.failed => tr('Search could not finish'),
    DoctorSearchPhase.idle => '',
  };

  /// The line under it.
  String get detail => switch (_phase) {
    DoctorSearchPhase.searching => switch (_speciality) {
      final speciality? => tr('Looking for a {title} who is free now.', {
        'title': tr(speciality.practitionerTitle),
      }),
      null => tr('Looking for a doctor who is free now.'),
    },
    DoctorSearchPhase.found => tr('Tap to see who can take your consultation.'),
    DoctorSearchPhase.empty => tr(
      'Nobody is online right now. Try again in a few minutes.',
    ),
    DoctorSearchPhase.failed => tr(
      _errorMessage ?? 'Something went wrong. Please try again.',
    ),
    DoctorSearchPhase.idle => '',
  };

  /// True once there is a listing worth opening.
  bool get hasResults => _phase == DoctorSearchPhase.found;

  /// Starts a search, replacing whatever the last one found.
  ///
  /// A second call while one is running is ignored rather than queued: a
  /// patient tapping Consult Now twice is asking for the same thing twice, and
  /// two searches would leave the dashboard reporting whichever finished last.
  Future<void> start({Speciality? speciality, bool instantOnly = false}) async {
    if (isSearching) return;

    final run = ++_run;

    _speciality = speciality;
    _instantOnly = instantOnly;
    _results = const [];
    _errorMessage = null;
    _phase = DoctorSearchPhase.searching;
    _update = const MatchingUpdate(active: MatchingStep.searching);
    _notify();

    _remaining = await _findDoctor.estimatedWait();
    if (run != _run) return;
    _startCountdown();

    try {
      final available = await _getDoctors(
        specialityId: speciality?.id,
        // Only doctors who can answer now. A listing that offers somebody who
        // cannot take the call is the difference between a list and a waiting
        // room.
        availableNow: true,
      );

      // A newer search started while this one was in flight. Its answer is the
      // one the patient is waiting on, and writing this one over it would show
      // them the result of a question they have already replaced.
      if (run != _run) return;

      _update = const MatchingUpdate(
        completed: {MatchingStep.searching},
        active: MatchingStep.checking,
      );
      _notify();

      await Future<void>.delayed(settleDelay);
      if (run != _run) return;

      _results = available;
      _phase = available.isEmpty
          ? DoctorSearchPhase.empty
          : DoctorSearchPhase.found;
      _update = MatchingUpdate(
        completed: const {MatchingStep.searching, MatchingStep.checking},
        active: MatchingStep.connecting,
        endedReason: available.isEmpty
            ? 'No doctors are available right now. Please try again shortly.'
            : null,
      );
    } on Failure catch (failure) {
      if (run != _run) return;
      _errorMessage = failure.message;
      _phase = DoctorSearchPhase.failed;
    } catch (_) {
      if (run != _run) return;
      _errorMessage = const Failure.unexpected().message;
      _phase = DoctorSearchPhase.failed;
    } finally {
      if (run == _run) {
        _stopCountdown();
        _notify();
      }
    }
  }

  /// Throws the search away: the patient cancelled it, or has seen what it
  /// found. The dashboard card goes with it.
  void clear() {
    if (_phase == DoctorSearchPhase.idle) return;

    // Bumped so an in-flight search cannot write its answer over a cleared
    // session and put the card back on a dashboard the patient just dismissed.
    _run++;
    _stopCountdown();
    _phase = DoctorSearchPhase.idle;
    _update = const MatchingUpdate();
    _results = const [];
    _errorMessage = null;
    _speciality = null;
    _instantOnly = false;
    _notify();
  }

  /// Notifies, deferring to the end of the frame if a build is in progress.
  ///
  /// This notifier is app-wide and is poked from `initState` — the search
  /// screen starts a search as it mounts, while the dashboard underneath is
  /// already listening. A plain `notifyListeners()` there marks an
  /// already-built `ListenableBuilder` dirty during the build phase, which
  /// Flutter asserts on: "setState() called during build".
  ///
  /// Deferring rather than asking every caller to schedule its own
  /// post-frame callback, because every caller would have to remember, and the
  /// one that forgot would crash a screen rather than fail a test.
  void _notify() {
    final phase = SchedulerBinding.instance.schedulerPhase;

    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
      return;
    }

    notifyListeners();
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds <= 0) {
        timer.cancel();
        return;
      }
      _remaining -= const Duration(seconds: 1);
      _notify();
    });
  }

  void _stopCountdown() {
    _countdown?.cancel();
    _countdown = null;
  }

  @override
  void dispose() {
    // Never called in the app — this lives for the process. Kept correct for
    // the tests, which build and tear one down per case.
    _stopCountdown();
    super.dispose();
  }
}
