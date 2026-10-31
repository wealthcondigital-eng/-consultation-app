import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/logging/auth_logger.dart';
import '../../../../core/recording/call_recorder.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../consultation/domain/usecases/answer_consultations.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/call_session.dart';
import '../../domain/repositories/call_repository.dart';

class CallController extends ChangeNotifier {
  CallController(this._repository, [this._consultations, this._newRecorder]);

  final CallRepository _repository;

  /// Closes the consultation record when the call ends, and opens it when the
  /// screen does. Optional because a call can be opened outside the instant
  /// flow — from a chat thread, say — where there is no record to keep.
  final ManageConsultationCall? _consultations;

  /// Makes the recorder for one attempt at the call — a fresh one per
  /// [initCall], so a Retry records rather than finding the last attempt's
  /// recorder already stopped. Null where nothing is ever recorded.
  final CallRecorder Function()? _newRecorder;

  CallRecorder? _recorder;

  /// True when this phone should record: set by [initCall] for the patient's
  /// side of a consented, non-anonymous consultation.
  bool _record = false;

  /// The longest the recorder waits, after connecting, for the other side's
  /// audio to start arriving. The speaker side is captured by attaching to
  /// WebRTC's playout, which only exists once remote audio is actually
  /// playing — so recording starts the moment it is, checked against the
  /// connection's statistics, and this is only the fallback.
  static const Duration recordingDelay = Duration(seconds: 4);

  /// How often the statistics are read while waiting.
  static const Duration _audioPoll = Duration(milliseconds: 150);

  /// True while this phone is recording the call.
  bool get isRecording => _recorder?.isRecording ?? false;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  CallSession? _session;
  Timer? _durationTimer;

  /// The last duration the server reported, and how long ago that was.
  ///
  /// The display ticks locally between reports so the seconds move smoothly,
  /// but every report re-anchors it — so a phone with a wrong clock, or one
  /// whose screen opened late, still shows the same duration as the other side.
  int _serverDuration = 0;
  int _sinceServerDuration = 0;

  CallSession? get session => _session;
  CallState get state => _session?.status ?? CallState.initializing;
  bool get isAudioMuted => _session?.isAudioMuted ?? false;
  bool get isVideoMuted => _session?.isVideoMuted ?? false;

  /// Before the session exists there is no route to report, and false — the
  /// earpiece — is the safer guess: a control that draws "speaker on" over
  /// silence is a control that gets tapped into the wrong state.
  bool get isSpeakerOn => _session?.isSpeakerOn ?? false;

  /// True for a voice consultation, which the controls and the screen both
  /// branch on.
  bool get isAudioCall => _session?.mode == ConsultationMode.audio;
  bool get isFrontCamera => _session?.isFrontCamera ?? true;
  int get durationInSeconds => _session?.durationInSeconds ?? 0;

  String get formattedDuration {
    final minutes = (durationInSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationInSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> initCall({
    required Doctor doctor,
    required ConsultationMode mode,
    required String channelId,
    String? consultationId,
    String peerId = 'self',
    bool isCaller = true,
    bool record = false,
  }) async {
    // A Retry's new attempt gets a new recorder; the old one's file, if any,
    // is already on its way through compose and upload.
    if (_recorder != null) await _stopRecording(_recorder);
    _record = record && consultationId != null;
    _recorder = _record ? _newRecorder?.call() : null;

    _session = CallSession(
      channelId: channelId,
      doctor: doctor,
      mode: mode,
      consultationId: consultationId,
      peerId: peerId,
      isCaller: isCaller,
      status: CallState.initializing,
    );
    notifyListeners();

    // Tells the API someone is actually in the room, which is what the doctor's
    // dashboard reads as a call under way. Deliberately not awaited into the
    // failure path below: a call that connects while this bookkeeping request
    // fails is still a call, and dropping the patient out of it would be the
    // worse outcome.
    if (consultationId != null) {
      unawaited(_reportJoined(consultationId));
    }

    try {
      // Once per controller. Retry comes back through here, and initialising
      // a renderer twice leaks the first texture and can leave the view
      // pointing at the one that was dropped.
      if (!_renderersReady) {
        await _repository.initializeRenderers(localRenderer, remoteRenderer);
        _renderersReady = true;
      }
      if (_disposed) return;

      await _repository.startCall(
        _session!,
        // Connecting two phones is several seconds of handshake, so the state
        // arrives here over time rather than as a return value.
        onStateChanged: (state) {
          // The first time the call connects, the clock starts at 00:00 —
          // whatever ran before was ringing, not talking. A reconnect keeps
          // counting from where it was.
          if (state == CallState.connected && _durationTimer == null) {
            _serverDuration = 0;
            _sinceServerDuration = 0;
            _session = _session?.copyWith(status: state, durationInSeconds: 0);
            _scheduleRecording();
          } else {
            _session = _session?.copyWith(status: state);
          }

          if (state == CallState.connected) _startTimer();
          // A dropped connection is the end of the recording as well; Retry
          // starts a new one.
          if (state == CallState.failed || state == CallState.ended) {
            unawaited(_stopRecording(_recorder));
          }
          notifyListeners();
        },
        onRemoteEnded: _onRemoteEnded,
        onDuration: (seconds) {
          // Only while connected: before then there is nothing to time, and
          // the screen shows Ringing… / Connecting… instead.
          if (_durationTimer == null) return;
          // The server's count, which both phones read, rather than each
          // counting from the moment its own screen opened. The local tick
          // between reports keeps the display moving smoothly.
          _serverDuration = seconds;
          _sinceServerDuration = 0;
          _session = _session?.copyWith(durationInSeconds: seconds);
          notifyListeners();
        },
      );
    } on Failure catch (failure) {
      _session = _session?.copyWith(
        status: CallState.failed,
        errorMessage: failure.message,
      );
      notifyListeners();
    } catch (e) {
      _session = _session?.copyWith(
        status: CallState.failed,
        errorMessage: tr('Failed to start call: {error}', {'error': e}),
      );
      notifyListeners();
    }
  }

  /// The other side hung up.
  ///
  /// Ends locally without calling `end` on the API — the record is already
  /// closed, which is how this was found out, and writing to it again would
  /// overwrite who ended the call.
  void _onRemoteEnded() {
    _durationTimer?.cancel();
    _durationTimer = null;

    // The recorders first: they read from the connection's tracks, which the
    // teardown closes.
    unawaited(
      _stopRecording(_recorder).whenComplete(() => _repository.endCall()),
    );

    _session = _session?.copyWith(status: CallState.ended);
    notifyListeners();
  }

  /// Starts the patient's recording as soon as the call is connected and the
  /// doctor's audio is coming through. See [recordingDelay].
  void _scheduleRecording() {
    final recorder = _recorder;
    final session = _session;
    final consultationId = session?.consultationId;
    if (!_record || recorder == null || consultationId == null) return;

    unawaited(() async {
      final deadline = DateTime.now().add(recordingDelay);
      while (DateTime.now().isBefore(deadline)) {
        if (_disposed || _ending || !identical(recorder, _recorder)) return;
        if (await _repository.remoteAudioFlowing()) break;
        await Future<void>.delayed(_audioPoll);
      }

      // The call may have ended, or been retried onto a new recorder, while
      // this waited.
      if (_disposed || _ending || !identical(recorder, _recorder)) return;
      if (state != CallState.connected && state != CallState.reconnecting) {
        return;
      }

      try {
        await recorder.start(
          consultationId: consultationId,
          video: session!.mode == ConsultationMode.video,
          remoteVideoTrack: _repository.remoteVideoTrack,
        );
      } catch (error) {
        // [CallRecorder] swallows its own failures; this is for anything
        // that slips past. The call carries on either way.
        AuthLogger.event('RECORDING · not started', {
          'consultation': consultationId,
          'reason': error.toString(),
        });
      }
      notifyListeners();
    }());
  }

  /// Never throws, and never holds up a hang-up for long: the recorders stop
  /// in well under a second, and the compose and upload that follow run on
  /// their own.
  Future<void> _stopRecording(CallRecorder? recorder) async {
    if (recorder == null) return;
    try {
      await recorder.stop();
    } catch (error) {
      AuthLogger.event('RECORDING · not stopped cleanly', {
        'reason': error.toString(),
      });
    }
    notifyListeners();
  }

  void _startTimer() {
    if (_durationTimer != null) return;

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session?.status != CallState.connected) return;

      _sinceServerDuration += 1;

      // Anchored to the server's last report rather than incremented from
      // whatever this phone happened to start at, so the two screens do not
      // drift apart over a long call.
      _session = _session!.copyWith(
        durationInSeconds: _serverDuration + _sinceServerDuration,
      );
      notifyListeners();
    });
  }

  Future<void> toggleAudioMute() async {
    if (_session == null) return;
    final newMuteState = !_session!.isAudioMuted;
    await _repository.toggleAudioMute(newMuteState);
    _session = _session!.copyWith(isAudioMuted: newMuteState);
    notifyListeners();
  }

  Future<void> toggleVideoMute() async {
    if (_session == null) return;
    final newMuteState = !_session!.isVideoMuted;
    await _repository.toggleVideoMute(newMuteState);
    _session = _session!.copyWith(isVideoMuted: newMuteState);
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (_session == null) return;
    await _repository.switchCamera();
    _session = _session!.copyWith(isFrontCamera: !_session!.isFrontCamera);
    notifyListeners();
  }

  /// Speaker or earpiece.
  ///
  /// The flag is only flipped once the platform has actually switched. A route
  /// change can be refused — a headset being unplugged mid-call, or the system
  /// owning the audio session for another call — and a button that lights up
  /// for a route the sound is not coming out of is worse than one that does
  /// not move.
  Future<void> toggleSpeaker() async {
    if (_session == null) return;

    final newSpeakerState = !_session!.isSpeakerOn;

    try {
      await _repository.toggleSpeaker(newSpeakerState);
    } catch (_) {
      return;
    }

    _session = _session!.copyWith(isSpeakerOn: newSpeakerState);
    notifyListeners();
  }

  /// True once a hang-up has started, so the back arrow, the back gesture and
  /// the red button pressed together end the call once.
  bool _ending = false;

  Future<void> endCall() async {
    if (_ending) return;
    _ending = true;

    _durationTimer?.cancel();
    _durationTimer = null;

    final consultationId = _session?.consultationId;

    // Before the teardown, which closes the tracks the recorders read from.
    await _stopRecording(_recorder);
    await _repository.endCall();
    _session = _session?.copyWith(status: CallState.ended);
    notifyListeners();

    // After the local teardown, so a slow or failing request cannot leave the
    // patient looking at a call they have already hung up on.
    if (consultationId != null) {
      try {
        await _consultations?.end(consultationId);
      } catch (_) {
        // The other side sees the peer connection close regardless, and the
        // record is closed by whoever hangs up next. Not worth an error on a
        // screen the user is leaving.
      }
    }
  }

  /// Marks the consultation as under way. Both parties call this; the first one
  /// through is what moves it, and the second is a no-op.
  Future<void> _reportJoined(String consultationId) async {
    try {
      await _consultations?.join(consultationId);
    } catch (_) {
      // Bookkeeping. The call itself does not depend on it.
    }
  }

  bool _renderersReady = false;
  bool _disposed = false;

  /// Quiet once disposed. The handshake reports state from timers and native
  /// callbacks that can land after the screen has gone, and notifying a
  /// disposed controller throws.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _durationTimer?.cancel();
    _durationTimer = null;
    unawaited(_teardown());
    super.dispose();
  }

  /// The call first, then the renderers it was drawing into — in that order.
  ///
  /// Disposing the renderers while the call still ran left the camera, the
  /// microphone and the peer connection open behind a closed screen, still
  /// writing into views that no longer existed. Leaving by the back gesture,
  /// or Close on a failed call, did exactly that, and the next call — a rejoin
  /// — started on top of it.
  Future<void> _teardown() async {
    await _stopRecording(_recorder);

    try {
      await _repository.endCall();
    } catch (error) {
      debugPrint('Could not close the call: $error');
    }

    try {
      await _repository.disposeRenderers(localRenderer, remoteRenderer);
    } catch (error) {
      debugPrint('Could not release the renderers: $error');
    }
  }
}
