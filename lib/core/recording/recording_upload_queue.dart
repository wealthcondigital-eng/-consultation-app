import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../error/failure.dart';
import '../logging/auth_logger.dart';
import '../network/api_client.dart';

/// One recorded consultation waiting to reach the server.
///
/// The file at [localPath] is sent as it is. It is either the phone's own copy
/// — never deleted, still the patient's to replay — or, for a video call, a
/// smaller copy made only for sending ([uploadCopy]), which goes once the
/// server has it while the HD original stays on the phone.
@immutable
class PendingRecording {
  const PendingRecording({
    required this.consultationId,
    required this.localPath,
    required this.mode,
    required this.durationSeconds,
    required this.mimeType,
    this.uploadCopy = false,
  });

  final String consultationId;
  final String localPath;

  /// `video` or `audio` — the consultation's mode, not what the file holds.
  final String mode;
  final int durationSeconds;
  final String mimeType;

  /// True when [localPath] was made only to be sent, and is deleted once it is.
  final bool uploadCopy;

  Map<String, Object?> toJson() => {
    'consultationId': consultationId,
    'localPath': localPath,
    'mode': mode,
    'durationSeconds': durationSeconds,
    'mimeType': mimeType,
    'uploadCopy': uploadCopy,
  };

  static PendingRecording? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['consultationId'];
    final path = value['localPath'];
    if (id is! String || path is! String) return null;

    return PendingRecording(
      consultationId: id,
      localPath: path,
      mode: value['mode'] == 'audio' ? 'audio' : 'video',
      durationSeconds: (value['durationSeconds'] as num?)?.toInt() ?? 0,
      mimeType: value['mimeType'] as String? ?? 'video/mp4',
      uploadCopy: value['uploadCopy'] == true,
    );
  }
}

/// Sends recorded consultations to the server in chunks, and keeps trying
/// until each one is in.
///
/// Persisted rather than held in memory, because the moment a recording is
/// ready — the call just ended — is exactly when people pocket the phone, lose
/// signal on the way out of a clinic, or swipe the app away. The queue picks
/// up on the next launch or resume, and the server's list of chunks it already
/// holds means a 40 MB recording that got to 30 MB sends the last 10, not all
/// 40 again.
///
/// | Method | Path                          |
/// | ------ | ----------------------------- |
/// | POST   | /recordings                   | create, or find the one in flight
/// | PUT    | /recordings/:id/chunks/:index | raw bytes
/// | POST   | /recordings/:id/complete      |
class RecordingUploadQueue extends ChangeNotifier {
  RecordingUploadQueue(
    this._client, {
    Future<SharedPreferences> Function()? preferences,
    bool Function()? canUpload,
    Duration? Function(int failures)? retryAfter,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _canUpload = canUpload ?? (() => true),
       _retryAfter = retryAfter ?? defaultRetryAfter;

  final ApiClient _client;
  final Future<SharedPreferences> Function() _preferences;

  /// False while signed out: every route here needs the bearer token, and a
  /// queue retrying into a 401 would end nothing but the battery.
  final bool Function() _canUpload;

  /// How long to wait after a pass that left something unsent. Null stops the
  /// automatic retry; the next resume or launch drains again regardless.
  final Duration? Function(int failures) _retryAfter;

  static const String storageKey = 'recordings.pendingUploads';

  /// What the server accepts in one recording. A bigger file stays on the
  /// phone only — see `CallRecorder`.
  static const int maxUploadBytes = 300 * 1024 * 1024;

  static const int _defaultChunkSize = 4 * 1024 * 1024;

  /// Refusals that retrying cannot change.
  static const Set<String> permanentFailureCodes = {
    'recording_not_allowed',
    'consultation_missing',
    'recording_too_large',
  };

  /// 30 s, 1 min, 2 min … capped at 30 min.
  static Duration defaultRetryAfter(int failures) => Duration(
    seconds: math.min(30 * math.pow(2, math.max(0, failures - 1)).toInt(), 1800),
  );

  List<PendingRecording> _pending = const [];
  bool _loaded = false;
  Future<void>? _draining;
  Timer? _retryTimer;
  int _failures = 0;
  bool _disposed = false;

  /// Recordings not yet on the server. Read after the first [drain] or
  /// [enqueue]; zero before the queue has looked at storage.
  int get pendingCount => _pending.length;

  /// True while a [drain] is sending — what an "Uploading recording…" line
  /// would show on.
  bool get isUploading => _draining != null;

  List<PendingRecording> get pending => List.unmodifiable(_pending);

  /// Files [item] and starts sending it. One entry per consultation: filing
  /// the same consultation again replaces the earlier entry.
  Future<void> enqueue(PendingRecording item) async {
    await _load();
    _pending = [
      ..._pending.where((p) => p.consultationId != item.consultationId),
      item,
    ];
    await _save();
    _notify();
    unawaited(drain());
  }

  /// Sends everything pending, one recording at a time.
  ///
  /// Single-flight: a call while a drain is under way joins it rather than
  /// starting a second one over the same files.
  Future<void> drain() {
    return _draining ??= _drainOnce().whenComplete(() {
      _draining = null;
      _notify();
    });
  }

  Future<void> _drainOnce() async {
    await _load();
    if (_pending.isEmpty || !_canUpload()) return;

    _retryTimer?.cancel();
    _retryTimer = null;
    _notify();

    var anyFailed = false;

    for (final item in List.of(_pending)) {
      if (_disposed || !_canUpload()) return;

      final file = File(item.localPath);
      if (!file.existsSync()) {
        // Deleted, or the app's storage was cleared. Nothing left to send,
        // and retrying a missing file forever would block nothing but waste
        // a request on every resume.
        AuthLogger.event('RECORDING · file gone, dropped from queue', {
          'consultation': item.consultationId,
          'path': item.localPath,
        });
        await _remove(item);
        continue;
      }

      try {
        await _upload(item, file);
        AuthLogger.event('RECORDING · uploaded', {
          'consultation': item.consultationId,
        });
        await _remove(item);
        // The smaller copy made for sending has done its job; the HD one
        // the patient replays is a different file.
        if (item.uploadCopy) _deleteQuietly(item.localPath);
      } on Failure catch (failure) {
        // The server will never take this one — anonymous, no consent, no
        // such consultation, too big. Dropped from the queue; the file stays
        // on the phone, where it is still the patient's copy.
        if (permanentFailureCodes.contains(failure.code)) {
          AuthLogger.event('RECORDING · refused for good, dropped', {
            'consultation': item.consultationId,
            'code': failure.code,
          });
          await _remove(item);
          continue;
        }

        anyFailed = true;
        AuthLogger.event('RECORDING · upload failed', {
          'consultation': item.consultationId,
          'reason': failure.message,
          'code': failure.code,
        });
        // A dead session fails everything after it the same way.
        if (failure.isSessionExpired) break;
      } catch (error) {
        anyFailed = true;
        AuthLogger.event('RECORDING · upload failed', {
          'consultation': item.consultationId,
          'reason': error.toString(),
        });
      }
    }

    if (!anyFailed) {
      _failures = 0;
      return;
    }

    _failures++;
    final wait = _retryAfter(_failures);
    if (wait != null && !_disposed) {
      _retryTimer = Timer(wait, () => unawaited(drain()));
    }
  }

  /// Create (or resume), send what the server does not have, complete.
  ///
  /// A `chunks_missing` on complete means a chunk the server counted never
  /// landed whole. Asking again re-reads which ones it holds, so the second
  /// pass sends exactly the gaps.
  Future<void> _upload(PendingRecording item, File file) async {
    for (var attempt = 1; ; attempt++) {
      try {
        await _uploadOnce(item, file);
        return;
      } on Failure catch (failure) {
        if (failure.code != 'chunks_missing' || attempt >= 3) rethrow;
      }
    }
  }

  Future<void> _uploadOnce(PendingRecording item, File file) async {
    final size = await file.length();

    final created = await _client.post(
      '/recordings',
      body: {
        'consultationId': item.consultationId,
        'mode': item.mode,
        'durationSeconds': item.durationSeconds,
        'sizeBytes': size,
        'mimeType': item.mimeType,
      },
    );

    final recording = created['recording'];
    if (recording is! Map) throw const Failure.unexpected();
    final id = recording['id'];
    if (id is! String || id.isEmpty) throw const Failure.unexpected();

    // Already assembled on the server — an earlier run got as far as
    // complete and lost the answer.
    if (recording['status'] == 'ready') return;

    final chunkSize = switch (created['chunkSize']) {
      final num value when value > 0 => value.toInt(),
      _ => _defaultChunkSize,
    };
    final received = <int>{
      for (final index in created['receivedChunks'] as List? ?? const [])
        if (index is num) index.toInt(),
    };
    final total = size == 0 ? 0 : (size + chunkSize - 1) ~/ chunkSize;

    // Cut by the server's chunk size, never a constant: it refuses any chunk
    // but the last that is not exactly that long.
    //
    // Read a chunk at a time. A consultation recording can run to hundreds of
    // megabytes, and holding it whole in memory is how an upload becomes an
    // out-of-memory kill.
    final handle = await file.open();
    try {
      for (var index = 0; index < total; index++) {
        if (received.contains(index)) continue;
        if (_disposed) return;

        final start = index * chunkSize;
        await handle.setPosition(start);
        final bytes = await handle.read(math.min(chunkSize, size - start));

        await _client.putBytes('/recordings/$id/chunks/$index', bytes);
      }
    } finally {
      await handle.close();
    }

    await _client.post('/recordings/$id/complete');
  }

  Future<void> _remove(PendingRecording item) async {
    _pending = [
      for (final p in _pending)
        if (p.consultationId != item.consultationId) p,
    ];
    await _save();
    _notify();
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final prefs = await _preferences();
      final raw = prefs.getString(storageKey);
      if (raw == null) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      _pending = [
        for (final entry in decoded) ?PendingRecording.fromJson(entry),
      ];
      _notify();
    } catch (error) {
      AuthLogger.event('RECORDING · queue unreadable', {
        'reason': error.toString(),
      });
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await _preferences();
      await prefs.setString(
        storageKey,
        jsonEncode([for (final p in _pending) p.toJson()]),
      );
    } catch (error) {
      AuthLogger.event('RECORDING · queue not saved', {
        'reason': error.toString(),
      });
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    super.dispose();
  }
}

void _deleteQuietly(String path) {
  try {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  } catch (_) {
    // A leftover upload copy costs some cache space, nothing more; the
    // system empties the cache folder on its own.
  }
}
