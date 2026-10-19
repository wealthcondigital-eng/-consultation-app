import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../logging/auth_logger.dart';

/// Whether the app can actually reach its backend.
///
/// Deliberately not "is there a network interface up". A phone attached to a
/// cafe's wifi that never got past the sign-in portal, or to a router whose
/// uplink is down, reports a healthy Wi-Fi connection and cannot load a thing —
/// which is exactly the state users describe as "it says connected but nothing
/// works". The only answer that means anything is whether a request to the API
/// comes back, so that is what this asks.
///
/// It learns the answer two ways:
///
///  * from real traffic — `ApiClient` reports every request that reached the
///    server and every one that could not, so an ordinary screen load is what
///    usually detects the drop, at no extra cost;
///  * by probing `/health` while offline, which is the only way back: nothing
///    else is being sent once the app is showing an offline screen, so without
///    this it would never find out the connection returned.
///
/// ## Why the app lifecycle is part of this
///
/// A failed request only means "there is no network" when the app was in a
/// position to have one. It is not, the moment it leaves the foreground: the
/// OS tears down open sockets, parks the radio and dozes the process, so the
/// requests that were in flight when the user swiped away all fail — with the
/// same `SocketException` a real outage produces. Believing them put the
/// offline screen up on a perfectly connected phone, and the user found it
/// waiting for them on the way back in.
///
/// So the rules are:
///
///  * while the app is not in the foreground, failed requests are ignored
///    outright, and nothing is probed — there is no usable network to ask
///    about, so a probe would fail and mean just as little;
///  * for a short settling window after the app comes back, a failed request
///    is not taken at face value either: Wi-Fi takes a moment to reassociate,
///    and the first screen reloading on resume usually beats it. Such a
///    failure is confirmed with a probe before anything is shown;
///  * an offline state no probe ever confirmed is re-checked on resume, and
///    stays hidden while that check runs — so a drop that happened only
///    because the app was backgrounded never reaches the screen at all.
///
/// A genuine outage is unaffected: a cold start with no network, a connection
/// lost while the user is looking at the app, and an outage still there when
/// they come back all show the screen exactly as before.
class ConnectivityMonitor extends ChangeNotifier {
  ConnectivityMonitor({http.Client? httpClient, this.retryInterval = _retry})
    : _http = httpClient ?? http.Client();

  /// How often to ask whether the connection is back.
  ///
  /// Short enough that reconnecting feels immediate, long enough not to sit in
  /// a tight loop against a dead network while the screen is up. The probe is a
  /// header and a two-line body, so the cost of asking is close to nothing.
  static const Duration _retry = Duration(seconds: 3);

  /// The probe's own timeout. Much shorter than `ApiClient.timeout`: this is
  /// not trying to complete work, only to find out whether anything answers,
  /// and a captive portal that holds connections open must not stall it.
  static const Duration probeTimeout = Duration(seconds: 6);

  /// The timeout for the two checks that gate the offline screen — the one on
  /// resume and the one that confirms a failure reported while settling.
  ///
  /// Shorter than [probeTimeout] because the app is visible and in use while
  /// these run. A dead network refuses in milliseconds; this bound only bites
  /// against something that accepts a connection and then says nothing, and
  /// there it is better to call it offline than to keep the user waiting.
  static const Duration gateProbeTimeout = Duration(seconds: 3);

  /// How long after returning to the foreground a failed request is read as
  /// "the radio is not up yet" rather than as evidence of an outage.
  static const Duration resumeSettleWindow = Duration(seconds: 4);

  /// How long to wait before confirming a failure reported while settling.
  /// Long enough for a reassociating network to finish; short enough that a
  /// real outage still surfaces promptly.
  static const Duration confirmDelay = Duration(milliseconds: 900);

  final http.Client _http;
  final Duration retryInterval;

  Timer? _retryTimer;
  Timer? _confirmTimer;
  bool _isProbing = false;

  bool _isOffline = false;

  /// Whether a probe — not merely a failed request — has established that the
  /// server is unreachable.
  ///
  /// This is what separates "the user is sitting in front of the offline
  /// screen on a dead network" from "a request failed and nobody has checked
  /// yet". Only the second is hidden and re-checked across a resume; the first
  /// must not flicker away every time the user glances at another app.
  bool _isOfflineConfirmed = false;

  /// Whether the app is in front of the user. Starts true: the first thing the
  /// app does is run, and a lifecycle event only arrives on a change.
  bool _isForeground = true;

  /// When the app last came back, or null if it has not been away. Opens the
  /// settling window described above.
  DateTime? _resumedAt;

  /// True while the post-resume re-check is in flight.
  bool _isRechecking = false;

  /// True from the first request that could not reach the server until one
  /// does. Nothing else — a 404, a 401, a 500 — counts: the server answering
  /// is the definition of being online, whatever it answered.
  ///
  /// Reads false while an unconfirmed offline state is being re-checked after
  /// a resume, so the screen goes up only once there is an answer.
  bool get isOffline => _isOffline && !_isRechecking;

  /// Called by `ApiClient` when a request reached the server.
  void reportReachable() {
    _cancelConfirm();
    _setOffline(false);
  }

  /// Called by `ApiClient` when a request could not reach it at all — a socket
  /// error, a refused connection, or a timeout.
  ///
  /// Believed on the spot only while the app is settled in the foreground,
  /// which is the only state in which a failed request is evidence of
  /// anything. See the class comment.
  void reportUnreachable() {
    if (_isOffline) return;

    // Backgrounded: this is the OS closing sockets, not the network going
    // away. Nothing to record, and nothing worth probing either — the radio is
    // parked, so the probe would fail and prove nothing.
    if (!_isForeground) return;

    // Just resumed: plausible either way, so ask rather than assume.
    if (_isSettling) {
      _confirmBeforeShowing();
      return;
    }

    _setOffline(true);
  }

  /// Asks right now instead of waiting for the next retry. Behind the offline
  /// screen's Try again button, where the user has usually just fixed
  /// something and should not be made to wait out a timer to find out.
  Future<bool> checkNow() async {
    final reachable = await _probe();
    _setOffline(!reachable);
    // The user asked and got an answer; that answer is as confirmed as it
    // gets, and must not be second-guessed by a later resume.
    if (!reachable) _isOfflineConfirmed = true;
    return reachable;
  }

  /// Driven by the widget above the navigator, which is the one part of the
  /// app guaranteed to be mounted for as long as there is an app to be
  /// offline. See `OfflineGate`.
  void onLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onResumed();
      // Everything else means the app is not in front of the user in a way it
      // can rely on: `inactive` covers the app switcher and a call arriving,
      // `hidden` and `paused` a real background, `detached` a teardown. The
      // difference does not matter here — in none of them can a socket be
      // trusted.
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _onBackgrounded();
    }
  }

  bool get _isSettling {
    final resumedAt = _resumedAt;
    return resumedAt != null &&
        DateTime.now().difference(resumedAt) < resumeSettleWindow;
  }

  void _onBackgrounded() {
    if (!_isForeground) return;
    _isForeground = false;

    _cancelConfirm();
    // Polling a parked radio wakes the process up to learn nothing. Whatever
    // the state is, it is re-established on the way back in.
    _stopRetrying();
  }

  void _onResumed() {
    final wasAway = !_isForeground;
    _isForeground = true;
    _resumedAt = DateTime.now();

    if (!wasAway || !_isOffline) return;

    if (_isOfflineConfirmed) {
      // A real outage, seen by a probe before the app was put away. Leave the
      // screen up and start asking again; there is nothing to hide.
      _startRetrying();
      return;
    }

    // Offline on the word of a failed request alone — quite possibly the very
    // request the OS killed on the way out. Show nothing until a probe rules.
    unawaited(_recheckAfterResume());
  }

  Future<void> _recheckAfterResume() async {
    _isRechecking = true;
    notifyListeners();

    try {
      if (await _probe(timeout: gateProbeTimeout)) {
        _setOffline(false);
        return;
      }

      // Still nothing. The screen appears as the flag below is cleared, and
      // the retry loop takes it from there.
      _isOfflineConfirmed = true;
      _startRetrying();
      AuthLogger.event('NETWORK · still unreachable after resume', {
        'api': AppConfig.apiBaseUrl,
      });
    } finally {
      _isRechecking = false;
      notifyListeners();
    }
  }

  /// Waits out the reassociation, then asks, and shows the screen only if the
  /// answer is still no. Single-shot: further failures inside the window fold
  /// into the check already pending.
  void _confirmBeforeShowing() {
    _confirmTimer ??= Timer(confirmDelay, () async {
      _confirmTimer = null;

      // Gone away again, or something got through in the meantime.
      if (!_isForeground || _isOffline) return;

      if (!await _probe(timeout: gateProbeTimeout)) {
        _setOffline(true);
        _isOfflineConfirmed = true;
      }
    });
  }

  void _cancelConfirm() {
    _confirmTimer?.cancel();
    _confirmTimer = null;
  }

  void _setOffline(bool offline) {
    if (_isOffline == offline) return;

    _isOffline = offline;
    // Reset on every transition: it is set again by whoever actually probed,
    // and a plain report has confirmed nothing.
    _isOfflineConfirmed = false;

    AuthLogger.event('NETWORK · ${offline ? 'unreachable' : 'reachable'}', {
      'api': AppConfig.apiBaseUrl,
    });

    if (offline) {
      _startRetrying();
    } else {
      _stopRetrying();
    }

    notifyListeners();
  }

  void _startRetrying() {
    // Nothing worth polling with while the app is away; `_onResumed` restarts
    // this.
    if (!_isForeground) return;

    _retryTimer ??= Timer.periodic(retryInterval, (_) async {
      if (_isProbing) return;
      if (await _probe()) {
        _setOffline(false);
      } else if (_isOffline) {
        // A probe has now seen the outage for itself, so it survives the user
        // switching away and back.
        _isOfflineConfirmed = true;
      }
    });
  }

  void _stopRetrying() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Any answer at all means the connection is back, including an error status:
  /// a 500 is the server having a bad day, not the phone being off the network.
  Future<bool> _probe({Duration? timeout}) async {
    if (_isProbing) return !_isOffline;
    _isProbing = true;

    try {
      await _http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/health'))
          .timeout(timeout ?? probeTimeout);
      return true;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } catch (_) {
      return false;
    } finally {
      _isProbing = false;
    }
  }

  @override
  void dispose() {
    _cancelConfirm();
    _stopRetrying();
    _http.close();
    super.dispose();
  }
}
