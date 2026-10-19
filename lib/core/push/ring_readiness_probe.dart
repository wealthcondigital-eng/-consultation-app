import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../device/call_device.dart';

/// One thing a phone has to allow before a closed app can ring.
enum RingCheckKind {
  /// Android 13+ asks. Refused, no call can show at all.
  notifications,

  /// Android 14+ asks separately for a call to take over the lock screen.
  /// Refused, the call still rings — as a heads-up notification, easy to miss.
  fullScreen,

  /// Battery optimisation can hold a push back for minutes, which for a
  /// ringing phone is the same as not ringing.
  battery,

  /// Xiaomi, Oppo, Vivo, Realme, OnePlus, Huawei and others keep a list of
  /// apps allowed to wake up once swiped away. Off the list, nothing rings.
  /// There is no way to read it, so the doctor confirms they have done it.
  autostart,
}

/// Asks the phone what it currently allows, and opens the place to change it.
abstract interface class RingReadinessProbe {
  /// Whether this check means anything on this phone at all.
  Future<bool> applies(RingCheckKind kind);

  Future<bool> isSatisfied(RingCheckKind kind);

  /// Asks for it, or opens the settings screen where it is changed.
  Future<void> fix(RingCheckKind kind);

  /// The doctor saying they have allowed auto-start — the one check that
  /// cannot be read back.
  Future<void> confirmAutostart();
}

/// The phone itself.
class PlatformRingReadinessProbe implements RingReadinessProbe {
  const PlatformRingReadinessProbe();

  static const String _autostartKey = 'ring_autostart_confirmed';

  /// Makers whose phones stop a swiped-away app from being woken by a push
  /// unless it is on their auto-start list. Matched on `Build.MANUFACTURER`.
  static const Set<String> _autostartMakers = {
    'xiaomi',
    'redmi',
    'poco',
    'oppo',
    'realme',
    'oneplus',
    'vivo',
    'iqoo',
    'huawei',
    'honor',
    'asus',
    'meizu',
    'letv',
    'tecno',
    'infinix',
    'itel',
  };

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> applies(RingCheckKind kind) async {
    // The ringing screen, and everything that keeps it working, is Android's.
    if (!_isAndroid) return false;

    if (kind == RingCheckKind.autostart) {
      final maker = (await CallDevice.manufacturer()).toLowerCase();
      return _autostartMakers.any(maker.contains);
    }

    return true;
  }

  @override
  Future<bool> isSatisfied(RingCheckKind kind) async {
    try {
      switch (kind) {
        case RingCheckKind.notifications:
          final settings = await FirebaseMessaging.instance
              .getNotificationSettings();
          return settings.authorizationStatus ==
                  AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
        case RingCheckKind.fullScreen:
          // True below Android 14, where there is nothing to grant.
          return await FlutterCallkitIncoming.canUseFullScreenIntent();
        case RingCheckKind.battery:
          return await CallDevice.isIgnoringBatteryOptimizations();
        case RingCheckKind.autostart:
          final prefs = await SharedPreferences.getInstance();
          return prefs.getBool(_autostartKey) ?? false;
      }
    } catch (_) {
      // A check that cannot be read is not shown as a problem: nagging a
      // doctor about something the phone will not even report is noise.
      return true;
    }
  }

  @override
  Future<void> fix(RingCheckKind kind) async {
    try {
      switch (kind) {
        case RingCheckKind.notifications:
          final settings = await FirebaseMessaging.instance.requestPermission();
          // Refused before: Android will not ask again, so the only way left
          // is the app's own settings page.
          if (settings.authorizationStatus == AuthorizationStatus.denied) {
            await CallDevice.openAppSettings();
          }
        case RingCheckKind.fullScreen:
          await FlutterCallkitIncoming.requestFullIntentPermission();
        case RingCheckKind.battery:
          await CallDevice.openBatterySettings();
        case RingCheckKind.autostart:
          await CallDevice.openAutostartSettings();
      }
    } catch (_) {
      // Nothing opened. The row stays as it was and can be tried again.
    }
  }

  @override
  Future<void> confirmAutostart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autostartKey, true);
    } catch (_) {}
  }
}

/// A phone that allows everything. The stand-in backend's, so screens and
/// tests that are not about ringing never show the setup card.
class ReadyRingReadinessProbe implements RingReadinessProbe {
  const ReadyRingReadinessProbe();

  @override
  Future<bool> applies(RingCheckKind kind) async => false;

  @override
  Future<bool> isSatisfied(RingCheckKind kind) async => true;

  @override
  Future<void> fix(RingCheckKind kind) async {}

  @override
  Future<void> confirmAutostart() async {}
}
