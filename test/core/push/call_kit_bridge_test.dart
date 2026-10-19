import 'dart:async';
import 'dart:convert';

import 'package:consultation_app/core/config/app_config.dart';
import 'package:consultation_app/core/network/api_client.dart';
import 'package:consultation_app/core/network/connectivity_monitor.dart';
import 'package:consultation_app/core/push/call_kit_bridge.dart';
import 'package:consultation_app/core/push/incoming_call_push.dart';
import 'package:consultation_app/core/push/push_service.dart';
import 'package:consultation_app/core/session/auth_session.dart';
import 'package:consultation_app/core/session/session_expiry.dart';
import 'package:consultation_app/core/session/session_store.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The plugin, as far as the bridge can see it.
class _FakePlatform implements CallKitPlatform {
  final StreamController<CallEvent?> controller =
      StreamController<CallEvent?>.broadcast();
  List<CallKitParams> active = [];
  final List<String> ended = [];

  @override
  Stream<CallEvent?> get events => controller.stream;

  @override
  Future<List<CallKitParams>> activeCalls() async => active;

  @override
  Future<void> endCall(String callKitId) async => ended.add(callKitId);
}

const _consultationId = '6ab61224679d9b7e982f09d3';

IncomingCallPush _call({
  ConsultationMode mode = ConsultationMode.video,
  String? concern = 'Chest pain since morning',
}) => IncomingCallPush(
  consultationId: _consultationId,
  channelId: 'consult-abc',
  mode: mode,
  callerName: 'Ravi Kumar',
  concern: concern,
  ringSeconds: 45,
);

CallKitParams _onPhone(String consultationId, {bool isAccepted = false}) =>
    CallKitParams(
      id: CallKitBridge.callKitIdFor(consultationId),
      isAccepted: isAccepted,
      extra: {'consultationId': consultationId},
    );

void main() {
  late _FakePlatform platform;
  late List<http.Request> requests;
  late CallKitBridge bridge;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platform = _FakePlatform();
    requests = [];

    final expiry = SessionExpiry();
    final client = ApiClient(
      AuthSession(InMemorySessionStore(), expiry),
      expiry,
      ConnectivityMonitor(),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      }),
    );
    bridge = CallKitBridge(client, platform);
  });

  tearDown(() => bridge.dispose());

  group('the call on the phone', () {
    test('its id is a UUID made from the consultation id', () {
      final id = CallKitBridge.callKitIdFor(_consultationId);

      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(id.replaceAll('-', ''), endsWith(_consultationId));
    });

    test('the same consultation always maps to the same id', () {
      // What lets a call-ended push, which names only the consultation, take
      // down the right call with nothing stored.
      expect(
        CallKitBridge.callKitIdFor(_consultationId),
        CallKitBridge.callKitIdFor(_consultationId),
      );
      expect(
        CallKitBridge.callKitIdFor(_consultationId),
        isNot(CallKitBridge.callKitIdFor('6ab61224679d9b7e982f09d4')),
      );
    });

    test('an id that is not hex still becomes a well-formed UUID', () {
      final id = CallKitBridge.callKitIdFor('c_1');

      expect(id, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(id, CallKitBridge.callKitIdFor('c_1'));
    });

    test('shows who is calling, why, and for how long', () {
      final params = CallKitBridge.paramsFor(_call());

      expect(params.id, CallKitBridge.callKitIdFor(_consultationId));
      expect(params.nameCaller, 'Ravi Kumar');
      expect(params.handle, 'Chest pain since morning');
      expect(params.duration, 45000);
      expect(params.android?.textAccept, 'Accept');
      expect(params.android?.textDecline, 'Decline');
      expect(params.android?.isShowFullLockedScreen, isTrue);
      expect(CallKitBridge.consultationIdOf(params), _consultationId);
    });

    test('marks a video call as video and an audio call as audio', () {
      expect(CallKitBridge.paramsFor(_call()).type, 1);
      expect(
        CallKitBridge.paramsFor(_call(mode: ConsultationMode.audio)).type,
        0,
      );
    });

    test('falls back to the kind of call when there is no concern', () {
      expect(
        CallKitBridge.paramsFor(_call(concern: null)).handle,
        'Video consultation',
      );
    });
  });

  group('answering on the ringing screen', () {
    test('an Accept is held for the doctor’s home to open', () async {
      bridge.start();

      platform.controller.add(
        CallEventActionCallAccept(_onPhone(_consultationId)),
      );
      await pumpEventQueue();

      expect(bridge.accepted.value, _consultationId);
      expect(bridge.take(), _consultationId);
      expect(bridge.accepted.value, isNull);
    });

    test('the same Accept arriving twice opens one call', () async {
      bridge.start();

      platform.controller.add(
        CallEventActionCallAccept(_onPhone(_consultationId)),
      );
      await pumpEventQueue();
      bridge.take();

      platform.controller.add(
        CallEventActionCallAccept(_onPhone(_consultationId)),
      );
      await pumpEventQueue();

      expect(bridge.accepted.value, isNull);
    });

    test('a Decline goes straight to the server', () async {
      bridge.start();

      platform.controller.add(
        CallEventActionCallDecline(_onPhone(_consultationId)),
      );
      await pumpEventQueue();

      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(
        requests.single.url.path,
        '/consultations/$_consultationId/decline',
      );
      expect(bridge.accepted.value, isNull);
    });
  });

  group('an Accept tapped while the app was killed', () {
    test('is found in the plugin’s record of the call', () async {
      platform.active = [_onPhone(_consultationId, isAccepted: true)];

      await bridge.recover();

      expect(bridge.accepted.value, _consultationId);
    });

    test('a call still ringing, not accepted, is left alone', () async {
      platform.active = [_onPhone(_consultationId)];

      await bridge.recover();

      expect(bridge.accepted.value, isNull);
    });

    test('is found in the note the background handler left', () async {
      await CallKitBridge.rememberAccepted(_consultationId);

      await bridge.recover();

      expect(bridge.accepted.value, _consultationId);

      // Read once: the note is gone, so a later resume does not reopen it.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('callkit_accepted'), isNull);
    });

    test('a note older than a ring is ignored', () async {
      SharedPreferences.setMockInitialValues({
        'callkit_accepted': jsonEncode({
          'consultationId': _consultationId,
          'at': DateTime.now()
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
        }),
      });

      await bridge.recover();

      expect(bridge.accepted.value, isNull);
    });

    test('the background handler notes an Accept', () async {
      await handleCallKitBackgroundEvent(
        CallEventActionCallAccept(_onPhone(_consultationId)),
      );

      await bridge.recover();

      expect(bridge.accepted.value, _consultationId);
    });
  });

  group('declining from the background, with no app running', () {
    test('sends the decline as the stored doctor', () async {
      final store = InMemorySessionStore();
      await store.write({'token': 'jwt-abc'});
      final sent = <http.Request>[];

      final ok = await CallKitBridge.declineInBackground(
        _consultationId,
        store: store,
        client: MockClient((request) async {
          sent.add(request);
          return http.Response('{}', 200);
        }),
      );

      expect(ok, isTrue);
      expect(
        sent.single.url.toString(),
        '${AppConfig.apiBaseUrl}/consultations/$_consultationId/decline',
      );
      expect(sent.single.headers['authorization'], 'Bearer jwt-abc');
    });

    test('sends nothing when nobody is signed in', () async {
      final sent = <http.Request>[];

      final ok = await CallKitBridge.declineInBackground(
        _consultationId,
        store: InMemorySessionStore(),
        client: MockClient((request) async {
          sent.add(request);
          return http.Response('{}', 200);
        }),
      );

      expect(ok, isFalse);
      expect(sent, isEmpty);
    });

    test('reports a refused decline rather than throwing', () async {
      final store = InMemorySessionStore();
      await store.write({'token': 'jwt-abc'});

      final ok = await CallKitBridge.declineInBackground(
        _consultationId,
        store: store,
        client: MockClient((_) async => http.Response('{}', 409)),
      );

      expect(ok, isFalse);
    });
  });

  group('call_ended push', () {
    test('names the consultation to stop ringing', () {
      expect(
        callEndedIn({
          'type': 'call_ended',
          'consultationId': _consultationId,
          'reason': 'cancelled',
        }),
        _consultationId,
      );
    });

    test('is not confused with anything else', () {
      expect(callEndedIn({'type': 'incoming_call'}), isNull);
      expect(callEndedIn({'type': 'call_ended'}), isNull);
    });
  });
}
