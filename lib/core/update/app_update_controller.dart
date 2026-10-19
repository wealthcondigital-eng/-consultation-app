import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Where an in-app update has got to.
enum AppUpdatePhase {
  /// Nothing to offer — no update, not a Play install, or not Android.
  none,

  /// A newer build is on Play. The banner shows "New version available".
  available,

  /// Play's consent sheet is up, or the download is queued.
  starting,

  /// Bytes are arriving; [AppUpdateController.progress] is meaningful.
  downloading,

  /// Downloaded, and being installed — the app is about to restart.
  installing,

  /// Something went wrong; the banner offers to try again.
  failed,
}

/// Google Play in-app updates, through `AppUpdateBridge.kt` — no plugin.
///
/// Flexible by default: the patient keeps using the app while the update
/// downloads, watches the banner fill to 100%, and the app then installs and
/// restarts itself. An update marked high-priority in the Play Console
/// (priority 4 or 5) is [isRequired]: its banner cannot be dismissed.
class AppUpdateController extends ChangeNotifier {
  AppUpdateController({bool? supported})
    : _supported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static const _methods = MethodChannel('consult/app_update');
  static const _events = EventChannel('consult/app_update/events');
  final bool _supported;

  StreamSubscription<Object?>? _subscription;

  AppUpdatePhase _phase = AppUpdatePhase.none;
  AppUpdatePhase get phase => _phase;

  double _progress = 0;

  /// 0–1 while downloading; 1 once installing.
  double get progress => _progress;

  bool _isRequired = false;

  /// High priority on Play: the banner stays until the update is taken.
  bool get isRequired => _isRequired;

  bool _dismissed = false;

  /// True once the patient tapped Later on the sheet. The profile's update
  /// card is where the offer lives from then on.
  bool get isDismissed => _dismissed;

  /// Whether there is an update to talk about at all.
  bool get isVisible => _phase != AppUpdatePhase.none;

  bool _prompted = false;

  /// Claims the once-per-launch sheet. True the first time only.
  bool claimPrompt() {
    if (_prompted) return false;
    _prompted = true;
    return true;
  }

  bool _checked = false;

  /// Asks Play once per launch. Safe to call from every home screen.
  Future<void> check() async {
    if (!_supported || _checked) return;
    _checked = true;

    _subscription ??= _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (_) {},
    );

    try {
      final info = await _methods.invokeMapMethod<String, Object?>('check');
      if (info == null || info['available'] != true) {
        // A download finished in an earlier session but was never installed.
        if (info?['downloaded'] == true) await _install();
        return;
      }

      final priority = (info['priority'] as num?)?.toInt() ?? 0;
      _isRequired = priority >= 4;
      _phase = info['downloaded'] == true
          ? AppUpdatePhase.installing
          : AppUpdatePhase.available;
      notifyListeners();

      if (info['downloaded'] == true) await _install();
    } on MissingPluginException {
      // Widget tests and any platform without the bridge.
    } on PlatformException {
      // Play unavailable — nothing to offer.
    }
  }

  /// The banner's Update button.
  Future<void> start() async {
    if (_phase != AppUpdatePhase.available && _phase != AppUpdatePhase.failed) {
      return;
    }

    _phase = AppUpdatePhase.starting;
    _progress = 0;
    notifyListeners();

    try {
      final started =
          await _methods.invokeMethod<bool>('start', {'immediate': false}) ??
          false;
      if (!started) _back();
    } on PlatformException {
      _phase = AppUpdatePhase.failed;
      notifyListeners();
    } on MissingPluginException {
      _back();
    }
  }

  /// "Later" on the sheet. The offer moves to the profile until next launch.
  void dismiss() {
    if (_isRequired) return;
    _dismissed = true;
    notifyListeners();
  }

  void _onEvent(Object? event) {
    if (event is! Map) return;

    final downloaded = (event['downloaded'] as num?)?.toDouble() ?? 0;
    final total = (event['total'] as num?)?.toDouble() ?? 0;

    switch (event['status']) {
      case 'pending':
        _phase = AppUpdatePhase.starting;
      case 'downloading':
        _phase = AppUpdatePhase.downloading;
        if (total > 0) _progress = (downloaded / total).clamp(0.0, 1.0);
      case 'downloaded':
        _progress = 1;
        _install();
        return;
      case 'installing' || 'installed':
        _phase = AppUpdatePhase.installing;
        _progress = 1;
      case 'failed':
        _phase = AppUpdatePhase.failed;
      case 'canceled':
        _back();
        return;
      default:
        return;
    }
    notifyListeners();
  }

  /// 100%: show it for a beat so the bar visibly completes, then hand over to
  /// Play, which installs and restarts the app.
  Future<void> _install() async {
    _phase = AppUpdatePhase.installing;
    _progress = 1;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 900));
    try {
      await _methods.invokeMethod<void>('complete');
    } on PlatformException {
      _phase = AppUpdatePhase.failed;
      notifyListeners();
    } on MissingPluginException {
      // Nothing to complete outside Android.
    }
  }

  /// The patient said no on Play's sheet: back to the offer.
  void _back() {
    _phase = AppUpdatePhase.available;
    _progress = 0;
    notifyListeners();
  }

  /// For tests: drive the banner without a platform.
  @visibleForTesting
  void debugSet(AppUpdatePhase phase, {double progress = 0, bool? required}) {
    _phase = phase;
    _progress = progress;
    if (required != null) _isRequired = required;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
