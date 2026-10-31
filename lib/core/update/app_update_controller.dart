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
  AppUpdateController({bool? supported, this.latestRelease})
    : _supported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// Reads `GET /app/latest` — the version name and Play's "What's new" for
  /// the newest release — so the popup can say which version it is offering.
  /// Optional: without it, or when it fails, the popup reads generically.
  final Future<Map<String, Object?>?> Function()? latestRelease;

  /// `1.0.17`, when the server knows the release Play is offering.
  String? _versionName;
  String? get versionName => _versionName;

  /// Play's "What's new", one entry per line. Empty when none was written.
  List<String> _releaseNotes = const [];
  List<String> get releaseNotes => _releaseNotes;

  /// The version code Play says is waiting. The popup is shown once per
  /// version, not once per launch, so a newer release still gets its popup.
  int? _availableVersionCode;

  DateTime? _checkedAt;

  /// How long a check stays good. Coming back to the app after this asks Play
  /// again, so a phone that keeps the app open for days still hears about a
  /// release.
  static const Duration _recheckAfter = Duration(hours: 1);

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

  int? _promptedFor;
  bool _promptedUnknown = false;

  /// Claims the popup for the version on offer. True once per version.
  bool claimPrompt() {
    final code = _availableVersionCode;
    if (code == null) {
      if (_promptedUnknown) return false;
      _promptedUnknown = true;
      return true;
    }
    if (_promptedFor == code) return false;
    _promptedFor = code;
    return true;
  }

  bool _checked = false;

  /// Asks Play again: on coming back to the app once the last check is
  /// stale, or straight away when [force] — an update notification arrived
  /// or was tapped, which also brings the popup back even after Later.
  Future<void> recheck({bool force = false}) async {
    if (!_supported) return;

    final stale =
        _checkedAt == null ||
        DateTime.now().difference(_checkedAt!) > _recheckAfter;
    if (!force && !stale) return;

    // Mid-download there is nothing to re-ask; the bar is already moving.
    if (_isBusy) return;

    if (force) {
      _dismissed = false;
      _promptedFor = null;
      _promptedUnknown = false;
    }
    _checked = false;
    await check();
  }

  bool get _isBusy =>
      _phase == AppUpdatePhase.starting ||
      _phase == AppUpdatePhase.downloading ||
      _phase == AppUpdatePhase.installing;

  /// Asks Play once per launch. Safe to call from every home screen.
  Future<void> check() async {
    if (!_supported || _checked) return;
    _checked = true;
    _checkedAt = DateTime.now();

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
      _availableVersionCode = (info['availableVersionCode'] as num?)?.toInt();
      await _readRelease();
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

  /// Fills [versionName] and [releaseNotes] from the server, but only when
  /// they describe the build Play is actually offering — notes for a
  /// different version would promise changes this update does not have.
  Future<void> _readRelease() async {
    final read = latestRelease;
    if (read == null) return;

    try {
      final release = (await read())?['release'];
      if (release is! Map) return;

      final code = (release['versionCode'] as num?)?.toInt();
      if (_availableVersionCode != null && code != _availableVersionCode) {
        return;
      }

      final name = release['versionName'];
      _versionName = name is String && name.isNotEmpty ? name : null;

      final notes = release['releaseNotes'];
      _releaseNotes = notes is String
          ? [
              for (final line in notes.split('\n'))
                if (line.replaceFirst(RegExp(r'^[\s•*\-–]+'), '').trim()
                    case final text when text.isNotEmpty)
                  text,
            ]
          : const [];
    } catch (_) {
      // Offline or an older server: the popup reads generically instead.
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
