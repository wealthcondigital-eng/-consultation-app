import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/device/call_device.dart';
import '../../../../core/l10n/tr.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../domain/entities/call_session.dart';
import '../screens/call_screen.dart';
import 'call_controller.dart';

/// The consultation call in progress, for as long as it lasts — not for as
/// long as its screen is open.
///
/// The call used to belong to the call screen: leaving the screen ended it.
/// So back hung up, and there was no way to look anything up mid-consultation
/// without cutting the other person off. Now the call lives here, the screen
/// is only a view onto it, and leaving the screen leaves the call running —
/// with [OngoingCallBar] across the top of every other screen as the way back,
/// as WhatsApp, Meet and the phone's own dialler all do.
///
/// One call at a time. Opening the call screen for the consultation already
/// under way re-attaches to it; opening it for a different one ends the old
/// one first.
class ActiveCall extends ChangeNotifier {
  ActiveCall(this._create);

  /// Makes a fresh controller — `sl<CallController>` in the app.
  final CallController Function() _create;

  CallController? _controller;
  CallArgs? _args;
  bool _screenOpen = false;
  bool _holdsDevice = false;

  /// The call's controller, or null when there is no call.
  CallController? get controller => _controller;

  /// What the call was opened with, so the screen can be reopened onto it.
  CallArgs? get args => _args;

  /// True while a call exists — connecting, connected or reconnecting.
  bool get isActive {
    final state = _controller?.state;
    return state == CallState.initializing ||
        state == CallState.connecting ||
        state == CallState.connected ||
        state == CallState.reconnecting;
  }

  /// True when the call screen is not on screen but the call is live — when
  /// the ongoing-call bar should show.
  bool get isAway => isActive && !_screenOpen && _controller?.session != null;

  /// The controller for [args]: the call already under way when it is the same
  /// consultation, otherwise a new one (ending any other call first).
  CallController attach(CallArgs args) {
    final current = _controller;
    final sameCall =
        current != null &&
        args.consultationId != null &&
        _args?.consultationId == args.consultationId &&
        current.state != CallState.ended &&
        current.state != CallState.failed;

    if (sameCall) return current;

    if (current != null) unawaited(_endAndRelease(current));

    final controller = _create()..addListener(_onControllerChanged);
    _controller = controller;
    _args = args;
    notifyListeners();
    return controller;
  }

  /// Whether [controller] has already been started — a re-attach must not
  /// start the call a second time.
  bool isStarted(CallController controller) =>
      identical(controller, _controller) && controller.session != null;

  void screenOpened() {
    _screenOpen = true;
    notifyListeners();
  }

  void screenClosed() {
    _screenOpen = false;
    notifyListeners();
  }

  /// Fires when a call ends while its screen is not open — the other side hung
  /// up while this person was elsewhere in the app. The app uses it to take a
  /// patient to the feedback screen, as the call screen would have.
  void Function(CallArgs args, int durationInSeconds)? onEndedAway;

  void _onControllerChanged() {
    final controller = _controller;
    if (controller == null) return;
    final state = controller.state;

    // The phone keeps the call alive behind the lock screen and other apps
    // from the moment it has its media until it ends — whichever screen, if
    // any, is showing it.
    if (state == CallState.connecting || state == CallState.connected) {
      _holdDevice();
    }

    if (state == CallState.ended || state == CallState.failed) {
      final args = _args;
      final duration = controller.durationInSeconds;
      final wasAway = !_screenOpen;

      if (state == CallState.ended) {
        _releaseDevice();
        // Let the screen (if open) navigate away first — it still draws from
        // this controller's renderers until it has gone — then let the
        // controller go. A failed call stays attached so its screen can offer
        // Retry.
        Future<void>.delayed(const Duration(seconds: 1), () {
          if (!identical(_controller, controller)) return;
          _controller = null;
          _args = null;
          controller.removeListener(_onControllerChanged);
          controller.dispose();
          notifyListeners();
        });
        if (wasAway && args != null) onEndedAway?.call(args, duration);
      }
    }

    notifyListeners();
  }

  /// Ends the call from outside its screen — the bar has no End button, but a
  /// new call replacing this one does.
  Future<void> end() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.endCall();
  }

  /// Lets go of a call whose screen closed before it ever started — a
  /// refused permission, or Close on a failed call.
  void discardIfNotStarted(CallController controller) {
    if (!identical(controller, _controller)) return;
    if (isActive &&
        controller.session != null &&
        controller.state != CallState.initializing) {
      return;
    }
    _controller = null;
    _args = null;
    controller.removeListener(_onControllerChanged);
    _releaseDevice();
    controller.dispose();
    notifyListeners();
  }

  Future<void> _endAndRelease(CallController controller) async {
    controller.removeListener(_onControllerChanged);
    _releaseDevice();
    try {
      await controller.endCall();
    } catch (_) {}
    controller.dispose();
  }

  void _holdDevice() {
    if (_holdsDevice) return;
    final args = _args;
    if (args == null) return;
    _holdsDevice = true;

    CallDevice.startCallService(
      video: args.mode == ConsultationMode.video,
      title: tr('Consultation with {name}', {'name': args.displayName}),
    );
    // A doctor who answered from the lock screen should not have to unlock
    // the phone to see the patient.
    CallDevice.showOverLockScreen(true);
  }

  void _releaseDevice() {
    if (!_holdsDevice) return;
    _holdsDevice = false;
    CallDevice.stopCallService();
    CallDevice.showOverLockScreen(false);
  }
}
