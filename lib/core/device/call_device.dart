import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logging/auth_logger.dart';

/// What a call needs from the phone itself that no plugin in the app offers.
///
/// Backed by `MainActivity.kt` on Android. Everywhere else — iOS, a widget
/// test — every call is a quiet no-op that reports the harmless answer, so a
/// caller never has to ask which platform it is on.
class CallDevice {
  const CallDevice._();

  static const MethodChannel _channel = MethodChannel('consult/call_device');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Keeps the microphone — and the camera, on a video call — running with
  /// the screen locked or the app behind another one. [title] is what the
  /// ongoing notification says.
  static Future<void> startCallService({
    required bool video,
    required String title,
  }) => _invoke('startCallService', {'video': video, 'title': title});

  static Future<void> stopCallService() => _invoke('stopCallService');

  /// Lets the call screen show over the lock screen and wake the display.
  /// Turned off again when the call ends.
  static Future<void> showOverLockScreen(bool on) =>
      _invoke('showOverLockScreen', {'on': on});

  /// Sends the app to the background without finishing it — what back does
  /// during a call. The activity, the Flutter engine and the call all stay
  /// alive; the foreground service's notification brings the screen back.
  static Future<void> moveToBackground() => _invoke('moveToBackground');

  /// Turns the screen off while the phone is against the ear. For a voice call
  /// on the earpiece only — on the speaker, the screen is being looked at.
  static Future<void> setProximityScreenOff(bool on) =>
      _invoke('setProximityScreenOff', {'on': on});

  /// True when Android will not hold the app's pushes back to save battery.
  static Future<bool> isIgnoringBatteryOptimizations() async =>
      await _invoke<bool>('isIgnoringBatteryOptimizations') ?? true;

  static Future<void> openBatterySettings() => _invoke('openBatterySettings');

  /// Opens the manufacturer's auto-start list, or the app's settings where
  /// the phone has none.
  static Future<void> openAutostartSettings() =>
      _invoke('openAutostartSettings');

  static Future<void> openAppSettings() => _invoke('openAppSettings');

  /// `Xiaomi`, `OPPO`, `samsung`… — empty off Android.
  static Future<String> manufacturer() async =>
      await _invoke<String>('manufacturer') ?? '';

  static Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!_isAndroid) return null;

    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } catch (error) {
      AuthLogger.event('DEVICE · $method failed', {'reason': '$error'});
      return null;
    }
  }
}
