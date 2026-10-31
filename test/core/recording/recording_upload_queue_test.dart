import 'dart:convert';
import 'dart:io';

import 'package:consultation_app/core/network/api_client.dart';
import 'package:consultation_app/core/network/connectivity_monitor.dart';
import 'package:consultation_app/core/recording/recording_upload_queue.dart';
import 'package:consultation_app/core/session/auth_session.dart';
import 'package:consultation_app/core/session/session_expiry.dart';
import 'package:consultation_app/core/session/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A stand-in for the recordings API: answers by route, and remembers every
/// request so a test can say what was — and was not — sent.
class _FakeServer {
  _FakeServer({
    this.receivedChunks = const [0],
    this.status = 'uploading',
    this.createError,
    this.completeStatus = 200,
  });

  static const int chunkSize = 4;
  final List<int> receivedChunks;
  final String status;
  final ({int status, String code})? createError;
  int completeStatus;

  final List<http.Request> requests = [];

  List<http.Request> get puts =>
      requests.where((r) => r.method == 'PUT').toList();

  int get completes =>
      requests.where((r) => r.url.path.endsWith('/complete')).length;

  ApiClient client() {
    final expiry = SessionExpiry();
    return ApiClient(
      AuthSession(InMemorySessionStore(), expiry),
      expiry,
      ConnectivityMonitor(),
      httpClient: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;

        if (request.method == 'POST' && path.endsWith('/recordings')) {
          final error = createError;
          if (error != null) {
            return _json(error.status, {
              'message': 'No',
              'error': {'code': error.code, 'message': 'No'},
            });
          }
          return _json(201, {
            'recording': {'id': 'rec-1', 'status': status},
            'chunkSize': chunkSize,
            'receivedChunks': receivedChunks,
          });
        }
        if (request.method == 'PUT' && path.contains('/chunks/')) {
          return _json(200, {'received': 1, 'receivedChunks': const []});
        }
        if (request.method == 'POST' && path.endsWith('/complete')) {
          if (completeStatus >= 400) {
            return _json(completeStatus, {
              'message': 'Server error',
              'error': {'code': 'boom', 'message': 'Server error'},
            });
          }
          return _json(200, {
            'recording': {'id': 'rec-1', 'status': 'ready'},
          });
        }
        return _json(404, {'message': 'Not found'});
      }),
    );
  }

  static http.Response _json(int status, Object body) =>
      http.Response(jsonEncode(body), status);
}

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('recording_queue_test');
    file = File('${dir.path}/c-1.mp4');
    // Ten bytes: with a 4-byte chunk size, chunks of 4, 4 and 2.
    await file.writeAsBytes(List<int>.generate(10, (i) => i));
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  PendingRecording item() => PendingRecording(
    consultationId: 'c-1',
    localPath: file.path,
    mode: 'video',
    durationSeconds: 42,
    mimeType: 'video/mp4',
  );

  RecordingUploadQueue queueFor(_FakeServer server) =>
      RecordingUploadQueue(server.client(), retryAfter: (_) => null);

  test('resumes: sends only the chunks the server does not have', () async {
    final server = _FakeServer(receivedChunks: const [0]);
    final queue = queueFor(server);

    await queue.enqueue(item());
    await queue.drain();

    final puts = server.puts;
    expect(puts.map((r) => r.url.path), [
      '/recordings/rec-1/chunks/1',
      '/recordings/rec-1/chunks/2',
    ]);
    // Cut by the server's chunk size; the last is the remainder.
    expect(puts[0].bodyBytes, [4, 5, 6, 7]);
    expect(puts[1].bodyBytes, [8, 9]);
    expect(puts.first.headers['content-type'], 'application/octet-stream');

    final create = server.requests.first;
    expect(jsonDecode(create.body), {
      'consultationId': 'c-1',
      'mode': 'video',
      'durationSeconds': 42,
      'sizeBytes': 10,
      'mimeType': 'video/mp4',
    });
    queue.dispose();
  });

  test('completes once and drops the item, keeping the file', () async {
    final server = _FakeServer();
    final queue = queueFor(server);

    await queue.enqueue(item());
    await queue.drain();

    expect(server.completes, 1);
    expect(queue.pendingCount, 0);
    expect(file.existsSync(), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(RecordingUploadQueue.storageKey), '[]');
    queue.dispose();
  });

  test('a copy made only for sending is deleted once it is sent', () async {
    final server = _FakeServer();
    final queue = queueFor(server);

    await queue.enqueue(
      PendingRecording(
        consultationId: 'c-1',
        localPath: file.path,
        mode: 'video',
        durationSeconds: 42,
        mimeType: 'video/mp4',
        uploadCopy: true,
      ),
    );
    await queue.drain();

    expect(server.completes, 1);
    // The HD original the patient replays is another file; this one was
    // only ever for the server.
    expect(file.existsSync(), isFalse);
    queue.dispose();
  });

  test('keeps the item when the upload fails, and retries later', () async {
    final server = _FakeServer(completeStatus: 500);
    final queue = queueFor(server);

    await queue.enqueue(item());
    await queue.drain();

    expect(queue.pendingCount, 1);

    // Persisted: a fresh queue — the next launch — still has it, and finishes
    // the job once the server is healthy.
    server.completeStatus = 200;
    final next = queueFor(server);
    await next.drain();
    expect(next.pendingCount, 0);
    queue.dispose();
    next.dispose();
  });

  test('a recording the server already holds is just marked done', () async {
    final server = _FakeServer(status: 'ready');
    final queue = queueFor(server);

    await queue.enqueue(item());
    await queue.drain();

    expect(server.puts, isEmpty);
    expect(server.completes, 0);
    expect(queue.pendingCount, 0);
    queue.dispose();
  });

  test('a permanent refusal drops the item but not the file', () async {
    final server = _FakeServer(
      createError: (status: 403, code: 'recording_not_allowed'),
    );
    final queue = queueFor(server);

    await queue.enqueue(item());
    await queue.drain();

    expect(queue.pendingCount, 0);
    expect(file.existsSync(), isTrue);
    queue.dispose();
  });

  test('one drain at a time', () async {
    final server = _FakeServer();
    final queue = queueFor(server);

    await queue.enqueue(item());
    await Future.wait([queue.drain(), queue.drain(), queue.drain()]);

    expect(server.completes, 1);
    queue.dispose();
  });
}
