import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

import '../logging/auth_logger.dart';
import 'recording_composer.dart';
import 'recording_upload_queue.dart';

/// Records one consultation on the patient's phone, then hands the result to
/// [RecordingComposer] and [RecordingUploadQueue].
///
/// flutter_webrtc's Android recorder takes **one** video track and **one**
/// side of the audio — the microphone (`INPUT`) or what the speaker plays
/// (`OUTPUT`) — never both. So a call is recorded as two files at once, which
/// the plugin allows because the two sides go through separate interceptors:
///
///  * **remote** — the doctor: their video track (on a video call) with the
///    `OUTPUT` audio, so their voice. `.mp4` (H.264 + AAC), or `.m4a` (AAC in
///    MPEG-4) when audio-only — the container the plugin's AudioFileRenderer
///    writes.
///  * **mic** — the patient's own voice, `INPUT`, audio-only `.m4a`.
///
/// After the call the two are mixed into one file and shrunk, on the phone,
/// before anything is uploaded.
///
/// Nothing here may end a call. Every platform call is wrapped, logged and
/// shrugged off: a consultation that loses its recording is a lesser outcome
/// than one that loses the doctor.
class CallRecorder extends ChangeNotifier {
  CallRecorder(
    this._composer,
    this._uploads, {
    MediaRecorder Function()? newRecorder,
  }) : _newRecorder = newRecorder ?? MediaRecorder.new;

  final RecordingComposer _composer;
  final RecordingUploadQueue _uploads;
  final MediaRecorder Function() _newRecorder;

  /// The plugin answers `stopRecordToFile` only for a recorder it knows about,
  /// so a stop after a start that half-failed would wait forever without this.
  static const Duration _stopTimeout = Duration(seconds: 5);

  MediaRecorder? _remote;
  MediaRecorder? _mic;
  String? _remotePath;
  String? _micPath;
  bool _remoteHasVideo = false;
  String? _consultationId;
  bool _videoCall = false;
  DateTime? _startedAt;

  /// Set by the first [stop]; a recorder is used for one call only.
  bool _stopped = false;
  Future<void>? _starting;

  /// True while either side is being written — what the badge shows on.
  bool get isRecording => _remote != null || _mic != null;

  /// Starts both recorders. Android only; a no-op elsewhere, and once
  /// [stop] has been called.
  ///
  /// [remoteVideoTrack] is the doctor's camera on a video call. Without it —
  /// an audio call, or a video call whose picture never arrived — the remote
  /// side is recorded as voice only.
  Future<void> start({
    required String consultationId,
    required bool video,
    MediaStreamTrack? remoteVideoTrack,
  }) {
    if (kIsWeb || !Platform.isAndroid) return Future.value();
    if (_stopped || isRecording || _starting != null) {
      return _starting ?? Future.value();
    }

    final starting = _start(consultationId, video, remoteVideoTrack);
    _starting = starting;
    return starting.whenComplete(() => _starting = null);
  }

  Future<void> _start(
    String consultationId,
    bool video,
    MediaStreamTrack? remoteVideoTrack,
  ) async {
    _consultationId = consultationId;
    _videoCall = video;

    final String dir;
    try {
      dir = (await getTemporaryDirectory()).path;
    } catch (error) {
      _log('RECORDING · no temp directory', error);
      return;
    }

    final withVideo = video && remoteVideoTrack != null;
    final remotePath =
        '$dir/${consultationId}_remote.${withVideo ? 'mp4' : 'm4a'}';
    final micPath = '$dir/${consultationId}_mic.m4a';

    try {
      _deleteQuietly(remotePath);
      final recorder = _newRecorder();
      await recorder.start(
        remotePath,
        videoTrack: withVideo ? remoteVideoTrack : null,
        audioChannel: RecorderAudioChannel.OUTPUT,
      );
      _remote = recorder;
      _remotePath = remotePath;
      _remoteHasVideo = withVideo;
    } catch (error) {
      _log('RECORDING · remote side not started', error);
    }

    try {
      _deleteQuietly(micPath);
      final recorder = _newRecorder();
      await recorder.start(micPath, audioChannel: RecorderAudioChannel.INPUT);
      _mic = recorder;
      _micPath = micPath;
    } catch (error) {
      _log('RECORDING · mic side not started', error);
    }

    if (isRecording) {
      _startedAt = DateTime.now();
      AuthLogger.event('RECORDING · started', {
        'consultation': consultationId,
        'remote': _remotePath ?? '(none)',
        'mic': _micPath ?? '(none)',
      });
    }
    notifyListeners();
  }

  /// Stops both recorders, then — in the background — composes, keeps and
  /// queues the result. Returns once the recorders have stopped, which is
  /// what has to happen before the peer connection is closed: the remote
  /// track is gone after that, and the speaker interceptor with it.
  ///
  /// Idempotent. Every way a call ends comes through here, often twice.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;

    // A start still under way finishes first, so nothing it opens is left
    // recording after the call.
    try {
      await _starting;
    } catch (_) {}

    final remote = _remote;
    final mic = _mic;
    _remote = null;
    _mic = null;
    if (remote == null && mic == null) return;

    await Future.wait([_stopQuietly(remote), _stopQuietly(mic)]);
    notifyListeners();

    final elapsed = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;

    unawaited(
      _finish(
        remotePath: remote == null ? null : _remotePath,
        micPath: mic == null ? null : _micPath,
        elapsedSeconds: elapsed,
      ),
    );
  }

  Future<void> _stopQuietly(MediaRecorder? recorder) async {
    if (recorder == null) return;
    try {
      await recorder.stop().timeout(_stopTimeout);
    } catch (error) {
      _log('RECORDING · stop failed', error);
    }
  }

  /// The phone's copy: 720p at about 2.5 Mbps, AAC at 128 kbps. Only as sharp
  /// as the call delivered — WebRTC lowers the picture on a weak connection.
  static const int hdHeight = 720;
  static const int hdVideoBitrate = 2500000;
  static const int hdAudioBitrate = 128000;

  /// Mix into the HD copy the phone keeps, make a smaller one to send, queue it.
  Future<void> _finish({
    required String? remotePath,
    required String? micPath,
    required int elapsedSeconds,
  }) async {
    final consultationId = _consultationId;
    if (consultationId == null) return;

    try {
      final inputs = [
        for (final path in [remotePath, micPath])
          if (path != null && _hasContent(path)) path,
      ];
      if (inputs.isEmpty) {
        AuthLogger.event('RECORDING · nothing was written', {
          'consultation': consultationId,
        });
        return;
      }

      final hasVideo = _remoteHasVideo && inputs.first == remotePath;
      final docs = await getApplicationDocumentsDirectory();
      final folder = Directory('${docs.path}/recordings');
      await folder.create(recursive: true);
      final output =
          '${folder.path}/$consultationId.${hasVideo ? 'mp4' : 'm4a'}';

      // The phone keeps the HD copy: 720p and clear audio, in the app's own
      // documents folder — private to the app, so it never shows in the
      // gallery or a file manager, and it goes when the app is uninstalled.
      var result = await _composer.compose(
        inputs: inputs,
        hasVideo: hasVideo,
        output: output,
        maxHeight: hdHeight,
        videoBitrate: hdVideoBitrate,
        audioBitrate: hdAudioBitrate,
      );

      // Mixing the two is the part most likely to be refused — some encoders
      // will not take two audio sequences at once. The doctor's side alone
      // still has their picture and voice, and is worth keeping.
      if (!result.ok && inputs.length > 1) {
        AuthLogger.event('RECORDING · mix failed, compressing one side', {
          'consultation': consultationId,
          'reason': result.error,
        });
        result = await _composer.compose(
          inputs: [inputs.first],
          hasVideo: hasVideo,
          output: output,
          maxHeight: hdHeight,
          videoBitrate: hdVideoBitrate,
          audioBitrate: hdAudioBitrate,
        );
      }

      final String keptPath;
      if (result.ok) {
        keptPath = output;
        for (final path in inputs) {
          _deleteQuietly(path);
        }
      } else {
        // Better than nothing: the first side, uncompressed, moved out of the
        // cache directory the system is free to empty.
        AuthLogger.event('RECORDING · compose failed, keeping raw file', {
          'consultation': consultationId,
          'reason': result.error,
        });
        final raw = inputs.first;
        keptPath = '${folder.path}/$consultationId.${raw.split('.').last}';
        await _move(raw, keptPath);
        for (final path in inputs.skip(1)) {
          _deleteQuietly(path);
        }
      }

      final size = await File(keptPath).length();
      final isVideoFile = keptPath.endsWith('.mp4') && hasVideo;
      final durationSeconds = result.ok && result.durationMs > 0
          ? (result.durationMs / 1000).round()
          : elapsedSeconds;

      AuthLogger.event('RECORDING · saved', {
        'consultation': consultationId,
        'path': keptPath,
        'bytes': size,
        'seconds': durationSeconds,
        'compressed': result.ok,
      });

      // The server gets a smaller copy of a video: 360p is plenty to replay a
      // consultation and a fraction of the upload. Made from the HD file in
      // the cache folder, and deleted once it has been sent. Audio is small
      // enough to send as it is.
      var uploadPath = keptPath;
      var uploadCopy = false;
      if (isVideoFile && result.ok) {
        final cache = await getTemporaryDirectory();
        final smaller = '${cache.path}/${consultationId}_upload.mp4';
        final shrunk = await _composer.compose(
          inputs: [keptPath],
          hasVideo: true,
          output: smaller,
        );
        if (shrunk.ok) {
          uploadPath = smaller;
          uploadCopy = true;
        } else {
          AuthLogger.event('RECORDING · upload copy failed, sending HD', {
            'consultation': consultationId,
            'reason': shrunk.error,
          });
        }
      }

      final uploadSize = await File(uploadPath).length();
      if (uploadSize > RecordingUploadQueue.maxUploadBytes) {
        AuthLogger.event('RECORDING · too large to upload, kept on phone', {
          'consultation': consultationId,
          'bytes': uploadSize,
        });
        if (uploadCopy) _deleteQuietly(uploadPath);
        return;
      }

      await _uploads.enqueue(
        PendingRecording(
          consultationId: consultationId,
          localPath: uploadPath,
          mode: _videoCall ? 'video' : 'audio',
          durationSeconds: durationSeconds,
          mimeType: isVideoFile ? 'video/mp4' : 'audio/mp4',
          uploadCopy: uploadCopy,
        ),
      );
    } catch (error) {
      _log('RECORDING · could not be finished', error);
    }
  }

  static bool _hasContent(String path) {
    try {
      final file = File(path);
      return file.existsSync() && file.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _move(String from, String to) async {
    _deleteQuietly(to);
    try {
      await File(from).rename(to);
    } on FileSystemException {
      // Cache and documents can sit on different volumes, where a rename
      // cannot cross.
      await File(from).copy(to);
      _deleteQuietly(from);
    }
  }

  static void _deleteQuietly(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  void _log(String title, Object error) {
    AuthLogger.event(title, {
      'consultation': _consultationId,
      'reason': error.toString(),
    });
  }
}
