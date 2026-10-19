import 'dart:io';

import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/core/network/api_client.dart';
import 'package:consultation_app/core/network/connectivity_monitor.dart';
import 'package:consultation_app/core/session/auth_session.dart';
import 'package:consultation_app/core/session/session_expiry.dart';
import 'package:consultation_app/core/session/session_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A client that answers or refuses to connect, switchable mid-test.
class _Network {
  bool isUp = true;
  int probes = 0;

  http.Client get client => MockClient((request) async {
    if (request.url.path.endsWith('/health')) probes++;
    if (!isUp) throw const SocketException('no route to host');
    return http.Response('{"ok":true}', 200);
  });
}

ApiClient _apiClient(ConnectivityMonitor monitor, http.Client network) {
  final expiry = SessionExpiry();
  return ApiClient(
    AuthSession(InMemorySessionStore(), expiry),
    expiry,
    monitor,
    httpClient: network,
  );
}

void main() {
  group('ConnectivityMonitor', () {
    test('starts out assuming the connection is fine', () {
      // Nothing has failed yet, and an offline screen shown on a hunch before
      // the first request is a worse first impression than a spinner.
      expect(ConnectivityMonitor().isOffline, isFalse);
    });

    test('an ordinary request that cannot reach the server is what detects '
        'the drop', () async {
      final network = _Network();
      final monitor = ConnectivityMonitor(httpClient: network.client);
      addTearDown(monitor.dispose);
      final client = _apiClient(monitor, network.client);

      network.isUp = false;
      await expectLater(client.get('/patients/me'), throwsA(isA<Failure>()));

      expect(monitor.isOffline, isTrue);
    });

    test(
      'a server that answers at all counts as online, whatever it said',
      () async {
        // A 500 is the server having a bad day; the phone is plainly on the
        // network, and covering the app with "no internet" would be a lie.
        final monitor = ConnectivityMonitor();
        addTearDown(monitor.dispose);
        final client = _apiClient(
          monitor,
          MockClient((_) async => http.Response('{"error":{}}', 500)),
        );

        monitor.reportUnreachable();
        expect(monitor.isOffline, isTrue);

        await expectLater(client.get('/patients/me'), throwsA(isA<Failure>()));
        expect(monitor.isOffline, isFalse);
      },
    );

    test('checking again reports the connection is back', () async {
      final network = _Network()..isUp = false;
      final monitor = ConnectivityMonitor(httpClient: network.client);
      addTearDown(monitor.dispose);

      monitor.reportUnreachable();
      expect(await monitor.checkNow(), isFalse);
      expect(monitor.isOffline, isTrue);

      network.isUp = true;

      expect(await monitor.checkNow(), isTrue);
      expect(monitor.isOffline, isFalse);
    });

    test('it keeps asking on its own while offline', () async {
      // The only way back: once the offline screen is up nothing else is being
      // sent, so without this the app would never learn the connection
      // returned and the user would be stuck behind a Try again button.
      final network = _Network()..isUp = false;
      final monitor = ConnectivityMonitor(
        httpClient: network.client,
        retryInterval: const Duration(milliseconds: 20),
      );
      addTearDown(monitor.dispose);

      monitor.reportUnreachable();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(network.probes, greaterThan(1));

      network.isUp = true;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(monitor.isOffline, isFalse);
    });

    test('it stops asking once the connection is back', () async {
      final network = _Network();
      final monitor = ConnectivityMonitor(
        httpClient: network.client,
        retryInterval: const Duration(milliseconds: 20),
      );
      addTearDown(monitor.dispose);

      monitor.reportUnreachable();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(monitor.isOffline, isFalse);

      final settled = network.probes;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(network.probes, settled, reason: 'no polling while online');
    });

    test('a request that fails while the app is backgrounded is ignored', () {
      // The one this whole lifecycle business exists for: the OS tears down
      // open sockets on the way out, so every request in flight fails at once —
      // on a phone whose network is perfectly fine. Believing them meant the
      // offline screen was already up when the user came back in.
      final monitor = ConnectivityMonitor();
      addTearDown(monitor.dispose);

      monitor.onLifecycleChanged(AppLifecycleState.paused);
      monitor.reportUnreachable();

      expect(monitor.isOffline, isFalse);
    });

    test('nothing is probed while the app is away', () async {
      final network = _Network()..isUp = false;
      final monitor = ConnectivityMonitor(
        httpClient: network.client,
        retryInterval: const Duration(milliseconds: 20),
      );
      addTearDown(monitor.dispose);

      monitor.reportUnreachable();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(network.probes, greaterThan(0));

      monitor.onLifecycleChanged(AppLifecycleState.paused);
      final parked = network.probes;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        network.probes,
        parked,
        reason: 'waking the process to poll a parked radio learns nothing',
      );
    });

    test('an unconfirmed drop is re-checked on resume and never shown', () async {
      final network = _Network();
      final monitor = ConnectivityMonitor(httpClient: network.client);
      addTearDown(monitor.dispose);

      // Reported by a request, on a network that is actually up — exactly what
      // a socket killed at backgrounding looks like.
      monitor.reportUnreachable();
      monitor.onLifecycleChanged(AppLifecycleState.paused);

      monitor.onLifecycleChanged(AppLifecycleState.resumed);
      // Hidden from the moment the app comes back, before the answer is in, so
      // there is no flash of the offline screen on the way to finding out.
      expect(monitor.isOffline, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(monitor.isOffline, isFalse);
    });

    test('a drop a probe confirmed is still there on resume', () async {
      // The other half: someone genuinely offline, looking at the screen, who
      // checks another app and comes back. Hiding it would be a lie, and a
      // flicker.
      final network = _Network()..isUp = false;
      final monitor = ConnectivityMonitor(
        httpClient: network.client,
        retryInterval: const Duration(milliseconds: 20),
      );
      addTearDown(monitor.dispose);

      monitor.reportUnreachable();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(monitor.isOffline, isTrue);

      monitor.onLifecycleChanged(AppLifecycleState.paused);
      monitor.onLifecycleChanged(AppLifecycleState.resumed);

      expect(monitor.isOffline, isTrue);

      // And the polling that was stopped on the way out is running again.
      network.isUp = true;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(monitor.isOffline, isFalse);
    });

    test('an outage that is still there on resume does surface', () async {
      final network = _Network();
      final monitor = ConnectivityMonitor(httpClient: network.client);
      addTearDown(monitor.dispose);

      monitor.reportUnreachable();
      monitor.onLifecycleChanged(AppLifecycleState.paused);
      network.isUp = false;

      monitor.onLifecycleChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(monitor.isOffline, isTrue);
    });

    test('a request that fails just after resume is confirmed first', () async {
      // Wi-Fi takes a moment to reassociate, and the screen reloading on resume
      // usually beats it. That first failure is not an outage.
      final network = _Network();
      final monitor = ConnectivityMonitor(httpClient: network.client);
      addTearDown(monitor.dispose);

      monitor.onLifecycleChanged(AppLifecycleState.paused);
      monitor.onLifecycleChanged(AppLifecycleState.resumed);

      monitor.reportUnreachable();
      expect(monitor.isOffline, isFalse);

      await Future<void>.delayed(
        ConnectivityMonitor.confirmDelay + const Duration(milliseconds: 80),
      );
      expect(monitor.isOffline, isFalse, reason: 'the probe got through');
    });

    test(
      'a real outage just after resume still shows, once confirmed',
      () async {
        final network = _Network()..isUp = false;
        final monitor = ConnectivityMonitor(httpClient: network.client);
        addTearDown(monitor.dispose);

        monitor.onLifecycleChanged(AppLifecycleState.paused);
        monitor.onLifecycleChanged(AppLifecycleState.resumed);

        monitor.reportUnreachable();
        expect(monitor.isOffline, isFalse);

        await Future<void>.delayed(
          ConnectivityMonitor.confirmDelay + const Duration(milliseconds: 120),
        );
        expect(monitor.isOffline, isTrue);
      },
    );

    test('the drop is announced once, not once per failed request', () async {
      final network = _Network()..isUp = false;
      final monitor = ConnectivityMonitor(httpClient: network.client);
      addTearDown(monitor.dispose);

      var announcements = 0;
      monitor.addListener(() => announcements++);

      monitor.reportUnreachable();
      monitor.reportUnreachable();
      monitor.reportUnreachable();

      expect(announcements, 1);
    });
  });
}
