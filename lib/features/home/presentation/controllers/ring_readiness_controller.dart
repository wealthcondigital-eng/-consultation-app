import 'package:flutter/foundation.dart';

import '../../../../core/push/ring_readiness_probe.dart';

/// One row of the setup list, and whether this phone passes it.
@immutable
class RingCheck {
  const RingCheck({required this.kind, required this.isSatisfied});

  final RingCheckKind kind;
  final bool isSatisfied;

  String get title => switch (kind) {
    RingCheckKind.notifications => 'Allow notifications',
    RingCheckKind.fullScreen => 'Show calls on the lock screen',
    RingCheckKind.battery => 'Remove battery restriction',
    RingCheckKind.autostart => 'Allow auto-start',
  };

  String get description => switch (kind) {
    RingCheckKind.notifications =>
      'Without them a patient’s call cannot ring at all.',
    RingCheckKind.fullScreen =>
      'So a call rings full screen, not as a small notification.',
    RingCheckKind.battery =>
      'Choose “Don’t optimise” or “Unrestricted” for Teleconsult, so calls '
          'are not held back.',
    RingCheckKind.autostart =>
      'Your phone stops closed apps from waking up. Turn Teleconsult on in '
          'the list that opens, then come back and confirm.',
  };

  /// What the button on an unmet row says.
  String get actionLabel => switch (kind) {
    RingCheckKind.notifications => 'Allow',
    RingCheckKind.fullScreen => 'Allow',
    RingCheckKind.battery => 'Open settings',
    RingCheckKind.autostart => 'Open settings',
  };
}

/// Whether this phone will ring for a patient with the app closed.
///
/// A doctor can be Online, with the server ringing their phone perfectly, and
/// still never hear it — because a setting on the phone is holding the call
/// back, and nothing about that is visible from inside the app. This reads
/// those settings and walks the doctor through fixing each one.
class RingReadinessController extends ChangeNotifier {
  RingReadinessController(this._probe);

  final RingReadinessProbe _probe;

  List<RingCheck> _checks = const [];

  /// Only the checks that mean something on this phone, in the order a
  /// doctor should fix them — the ones that stop a call outright first.
  List<RingCheck> get checks => _checks;

  List<RingCheck> get missing =>
      _checks.where((check) => !check.isSatisfied).toList();

  bool _hasLoaded = false;
  bool get hasLoaded => _hasLoaded;

  /// True once every check this phone has is met. False until loaded, so
  /// nothing claims the phone is ready before it has been asked.
  bool get isReady => _hasLoaded && missing.isEmpty;

  bool _isRefreshing = false;

  /// Reads everything again. Called on load and whenever the app comes back
  /// to the front — which is what happens after each settings screen.
  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final checks = <RingCheck>[];
      for (final kind in RingCheckKind.values) {
        if (!await _probe.applies(kind)) continue;
        checks.add(
          RingCheck(kind: kind, isSatisfied: await _probe.isSatisfied(kind)),
        );
      }

      _checks = checks;
      _hasLoaded = true;
    } finally {
      _isRefreshing = false;
    }

    notifyListeners();
  }

  /// Asks for the permission or opens the settings screen for [kind].
  ///
  /// Re-read straight afterwards for the two that answer in place — a
  /// permission dialog. The settings screens answer when the doctor comes
  /// back, which [refresh] on resume picks up.
  Future<void> fix(RingCheckKind kind) async {
    await _probe.fix(kind);

    if (kind == RingCheckKind.notifications ||
        kind == RingCheckKind.fullScreen) {
      await refresh();
    }
  }

  /// The doctor saying auto-start is allowed. Taken on trust: the phone has no
  /// way to say.
  Future<void> confirmAutostart() async {
    await _probe.confirmAutostart();
    await refresh();
  }
}
