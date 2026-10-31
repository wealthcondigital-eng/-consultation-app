import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/consultation/domain/entities/consultation_mode.dart';
import '../config/app_config.dart';
import '../logging/auth_logger.dart';
import '../network/api_client.dart';
import '../session/session_store.dart';
import 'incoming_call_push.dart';

/// Runs when the doctor answers the ringing screen while the app is killed.
///
/// A **top-level function** for the same reason as `handleBackgroundMessage`:
/// the plugin starts a Dart isolate of its own for it, with none of the app's
/// state. Only two answers need anything done here —
///
///  * **Decline**, which has to reach the server now. Nothing else will tell
///    it: the app is not running and is not about to be, so without this the
///    patient waits out the whole ring for a doctor who has already said no.
///  * **Accept**, which launches the app. The answer itself is sent from the
///    app once it is up (see [CallKitBridge.recover]); this only leaves a note
///    saying which call it was, in case the app starts before the plugin has
///    recorded the call as accepted.
@pragma('vm:entry-point')
Future<void> handleCallKitBackgroundEvent(CallEvent event) async {
  switch (event) {
    case CallEventActionCallDecline(:final callKitParams):
      final id = CallKitBridge.consultationIdOf(callKitParams);
      if (id != null) await CallKitBridge.declineInBackground(id);
    case CallEventActionCallAccept(:final callKitParams):
      final id = CallKitBridge.consultationIdOf(callKitParams);
      if (id != null) await CallKitBridge.rememberAccepted(id);
    default:
      break;
  }
}

/// What [CallKitBridge] needs from the plugin, behind an interface so a test
/// can drive it without a phone.
abstract interface class CallKitPlatform {
  Stream<CallEvent?> get events;
  Future<List<CallKitParams>> activeCalls();
  Future<void> endCall(String callKitId);
}

class _PluginCallKitPlatform implements CallKitPlatform {
  const _PluginCallKitPlatform();

  @override
  Stream<CallEvent?> get events => FlutterCallkitIncoming.onEvent;

  @override
  Future<List<CallKitParams>> activeCalls() =>
      FlutterCallkitIncoming.activeCalls();

  @override
  Future<void> endCall(String callKitId) =>
      FlutterCallkitIncoming.endCall(callKitId);
}

/// The phone's own incoming-call screen, wired to consultations.
///
/// This is what rings a doctor whose app is in the background or killed: a
/// full-screen call over the lock screen, with the ringtone looping and Accept
/// and Decline on it — the same thing a phone call looks like, drawn by the
/// system rather than by a Flutter screen that is not running.
///
/// The in-app banner still exists and still answers while the app is open.
/// This covers the rest of the time.
///
/// Static parts are used from the background isolates, which have no service
/// locator; the instance is the app's side, registered once.
class CallKitBridge {
  /// [_platform] is the plugin itself outside a test.
  CallKitBridge(
    this._client, [
    this._platform = const _PluginCallKitPlatform(),
  ]);

  final ApiClient _client;
  final CallKitPlatform _platform;

  StreamSubscription<CallEvent?>? _events;

  /// A consultation the doctor accepted on the ringing screen, waiting for the
  /// doctor's home to take it and open the call.
  ///
  /// A value rather than a callback because the answer usually arrives before
  /// anything can act on it: Accept launches the app, and the home screen is
  /// several hundred milliseconds and a splash screen away.
  final ValueNotifier<String?> accepted = ValueNotifier<String?>(null);

  /// Every call already handed over, so the same Accept arriving by two routes
  /// — the event, the note, the plugin's own record — opens one call.
  final Set<String> _handled = {};

  static const String _acceptedKey = 'callkit_accepted';

  /// How long an Accept note stays worth acting on. A note older than a ring
  /// is a call that has long since gone to somebody else.
  static const Duration _acceptedLifetime = Duration(minutes: 1);

  /// Starts listening for answers. Called once from `main`, after the session
  /// is restored.
  void start() {
    if (_events != null) return;

    try {
      _events = _platform.events.listen(
        _onEvent,
        // No plugin (a test, a desktop build) is not an error worth surfacing.
        onError: (Object error) {
          AuthLogger.event('CALLKIT · events unavailable', {
            'reason': '$error',
          });
        },
      );
    } catch (error) {
      AuthLogger.event('CALLKIT · events unavailable', {'reason': '$error'});
    }

    unawaited(recoverSoon());
  }

  void _onEvent(CallEvent? event) {
    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        final id = consultationIdOf(callKitParams);
        if (id != null) _offer(id);
      case CallEventActionCallDecline(:final callKitParams):
        final id = consultationIdOf(callKitParams);
        if (id != null) {
          _ringing.remove(id);
          unawaited(_decline(id));
        }
      case CallEventActionCallEnded(:final callKitParams):
        final id = consultationIdOf(callKitParams);
        if (id != null) _ringing.remove(id);
      default:
        break;
    }
  }

  /// Picks up an Accept that happened while the app was not listening.
  ///
  /// Two places to look, because either can be the one that made it: the
  /// plugin's own record of the call, which it writes before launching the
  /// app, and the note the background handler leaves. Called at start-up and
  /// again when the doctor's home opens.
  Future<void> recover() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Written by another isolate, which this one's cache has not seen.
      await prefs.reload();

      final raw = prefs.getString(_acceptedKey);
      if (raw != null) {
        await prefs.remove(_acceptedKey);

        final note = jsonDecode(raw) as Map<String, dynamic>;
        final at = DateTime.tryParse(note['at'] as String? ?? '')?.toLocal();
        final id = note['consultationId'] as String?;

        if (id != null &&
            at != null &&
            DateTime.now().difference(at) < _acceptedLifetime) {
          _offer(id);
        }
      }
    } catch (error) {
      AuthLogger.event('CALLKIT · no accept note', {'reason': '$error'});
    }

    try {
      for (final call in await _platform.activeCalls()) {
        final id = consultationIdOf(call);
        if (call.isAccepted && id != null) _offer(id);
      }
    } catch (error) {
      AuthLogger.event('CALLKIT · no active calls', {'reason': '$error'});
    }
  }

  /// Calls this process has put on the ringing screen, so the same call
  /// arriving by push and by poll rings once.
  final Set<String> _ringing = {};

  /// Rings for a call the app found itself, with the app open.
  ///
  /// The same ringing screen a closed app gets — the looping ringtone and the
  /// call vibration — because an open app is no reason to ring more quietly.
  /// The in-app banner alone made no sound at all, and a notification on the
  /// call channel made one short tone: a doctor whose phone was on the desk
  /// with the app open never heard the call.
  ///
  /// A call already up (rung by its push a moment earlier) is left alone.
  Future<void> ring(IncomingCallPush call) async {
    if (_handled.contains(call.consultationId)) return;
    if (!_ringing.add(call.consultationId)) return;

    try {
      final id = callKitIdFor(call.consultationId);
      final active = await _platform.activeCalls();
      if (active.any((c) => c.id == id)) return;
    } catch (_) {
      // Unknown: ringing twice is better than not ringing.
    }

    await show(call);
  }

  /// Stops ringing for a call that went away while the app was watching — the
  /// patient gave up, or it rang out and went to another doctor.
  Future<void> stopRinging(String consultationId) async {
    if (!_ringing.remove(consultationId)) return;
    await end(consultationId);
  }

  /// [recover], now and again over the next few seconds.
  ///
  /// This is what makes Accept on a locked or backgrounded phone open the call.
  /// Answering brings the app forward at the same moment the plugin writes
  /// down that the call was accepted, in another process — and the app very
  /// often wins: it resumed, looked once, found nothing yet, and never looked
  /// again. The doctor was left on the dashboard with the call still waiting
  /// to be started by hand. Looking again for a few seconds catches a note
  /// that lands just after the app does; [_handled] makes the repeats free.
  Future<void> recoverSoon() async {
    for (final delay in const [
      Duration.zero,
      Duration(milliseconds: 700),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ]) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      await recover();
    }
  }

  /// The pending accepted call, handed over once.
  String? take() {
    final id = accepted.value;
    accepted.value = null;
    return id;
  }

  void _offer(String consultationId) {
    _ringing.remove(consultationId);
    if (!_handled.add(consultationId)) return;

    AuthLogger.event('CALLKIT · accepted', {'consultation': consultationId});
    accepted.value = consultationId;
  }

  Future<void> _decline(String consultationId) async {
    AuthLogger.event('CALLKIT · declined', {'consultation': consultationId});

    try {
      await _client.post('/consultations/$consultationId/decline');
    } catch (error) {
      // The ring times out on the server anyway; a decline that did not land
      // costs the patient the rest of it, not the consultation.
      AuthLogger.event('CALLKIT · decline failed', {'reason': '$error'});
    }
  }

  // --- Used from the background isolates -----------------------------------

  /// Puts the full-screen ringing call up.
  static Future<void> show(IncomingCallPush call) async {
    try {
      await FlutterCallkitIncoming.showCallkitIncoming(paramsFor(call));
    } catch (error) {
      AuthLogger.event('CALLKIT · could not ring', {'reason': '$error'});
    }
  }

  /// Takes the ringing screen, or the ongoing-call notification after an
  /// Accept, down.
  static Future<void> end(String consultationId) async {
    try {
      await FlutterCallkitIncoming.endCall(callKitIdFor(consultationId));
    } catch (_) {
      // Nothing up, or no plugin. Either way there is nothing left to end.
    }
  }

  /// Hands the phone's audio back before a call screen opens.
  ///
  /// On Android the ringing screen is a real telecom call, and once answered
  /// it owns the audio session: the call audio mode and the route. Ending it
  /// gives those back — but Android resets the audio mode to normal as it
  /// does, and if that lands after WebRTC has set up its own call audio, the
  /// voice call loses its earpiece route and its echo cancellation mid-sentence.
  /// So it is ended first, every call on the phone, and given a moment to
  /// settle before anything opens the microphone.
  static Future<void> releaseAudio() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {
      // No plugin, or nothing up: nothing to release.
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  /// Lets the plugin run [handleCallKitBackgroundEvent] in this process.
  ///
  /// Must be called in the process that shows the call — the background
  /// isolate a push wakes — or a Decline tapped while the app is killed has no
  /// Dart to deliver to.
  static Future<void> registerBackgroundHandler() async {
    try {
      await FlutterCallkitIncoming.onBackgroundMessage(
        handleCallKitBackgroundEvent,
      );
    } catch (error) {
      AuthLogger.event('CALLKIT · no background handler', {'reason': '$error'});
    }
  }

  /// The ringing screen for one consultation.
  @visibleForTesting
  static CallKitParams paramsFor(IncomingCallPush call) {
    return CallKitParams(
      id: callKitIdFor(call.consultationId),
      nameCaller: call.callerName,
      appName: 'Consultation',
      // What shows under the name. The concern is the doctor's reason to
      // answer; failing that, what kind of call it is.
      handle: call.concern ?? call.modeLabel,
      type: call.mode == ConsultationMode.video ? 1 : 0,
      // Rings for as long as the server holds it for this doctor, then shows
      // as missed rather than buzzing after the patient has moved on.
      duration: call.ringFor.inMilliseconds,
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed consultation',
      ),
      callingNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Consultation in progress',
      ),
      extra: <String, dynamic>{
        'consultationId': call.consultationId,
        'channelId': call.channelId,
        'mode': call.mode.name,
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        // The brand teal behind the caller, and green for Accept.
        backgroundColor: '#1B7B80',
        actionColor: '#16A34A',
        textColor: '#ffffff',
        ringtonePath: 'system_ringtone_default',
        incomingCallNotificationChannelName: 'Incoming consultations',
        missedCallNotificationChannelName: 'Missed consultations',
        isShowFullLockedScreen: true,
        isImportant: true,
        textAccept: 'Accept',
        textDecline: 'Decline',
      ),
      ios: const IOSParams(
        handleType: 'generic',
        supportsVideo: true,
        audioSessionMode: 'default',
        audioSessionActive: true,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );
  }

  /// The call's id on the phone, which iOS insists is a UUID.
  ///
  /// Derived rather than generated, so a `call_ended` push naming only the
  /// consultation can find the call to take down without anything having been
  /// stored. A consultation id is a 24-hex-digit ObjectId; padded to 32 it is
  /// a UUID's worth of hex. Anything else is hashed to fill the same shape.
  static String callKitIdFor(String consultationId) {
    final isHex = RegExp(r'^[0-9a-fA-F]{1,32}$').hasMatch(consultationId);
    final hex = isHex
        ? consultationId.toLowerCase().padLeft(32, '0')
        : _hexHash(consultationId);

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  static String _hexHash(String value) {
    // FNV-1a, four times with different seeds, for 128 bits of hex. Not a
    // security property — only a stable, well-spread mapping.
    final buffer = StringBuffer();
    for (var seed = 0; seed < 4; seed++) {
      var hash = 0x811c9dc5 ^ seed;
      for (final unit in utf8.encode(value)) {
        hash ^= unit;
        hash = (hash * 0x01000193) & 0xffffffff;
      }
      buffer.write(hash.toRadixString(16).padLeft(8, '0'));
    }
    return buffer.toString();
  }

  /// Which consultation a call on the phone is for.
  static String? consultationIdOf(CallKitParams call) {
    final id = call.extra?['consultationId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// Leaves a note that [consultationId] was accepted, for [recover].
  static Future<void> rememberAccepted(String consultationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _acceptedKey,
        jsonEncode({
          'consultationId': consultationId,
          'at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (error) {
      AuthLogger.event('CALLKIT · could not note accept', {'reason': '$error'});
    }
  }

  /// Declines from a background isolate, where there is no `ApiClient`.
  ///
  /// Reads the stored session directly — the same record `AuthSession`
  /// restores from — and sends the one request. A signed-out phone has no
  /// token, and then there is nothing to send: the ring times out.
  static Future<bool> declineInBackground(
    String consultationId, {
    SessionStore store = const PreferencesSessionStore(),
    http.Client? client,
  }) async {
    final http.Client http_ = client ?? http.Client();

    try {
      final session = await store.read();
      final token = session?['token'];
      if (token is! String || token.isEmpty) return false;

      final response = await http_
          .post(
            Uri.parse(
              '${AppConfig.apiBaseUrl}/consultations/$consultationId/decline',
            ),
            headers: {
              'content-type': 'application/json',
              'accept': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: '{}',
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      if (client == null) http_.close();
    }
  }

  void dispose() {
    _events?.cancel();
    _events = null;
    accepted.dispose();
  }
}
