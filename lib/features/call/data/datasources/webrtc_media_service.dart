import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/error/failure.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../domain/entities/call_session.dart';
import 'call_signalling_client.dart';

/// Camera and microphone, the peer connection, and the handshake that joins two
/// phones.
///
/// What changed when this stopped being a demo:
///
///  * **ICE servers come from the server.** STUN alone connects two devices on
///    the same wifi and fails between two phones on mobile data, where
///    carrier-grade NAT means neither can be reached directly and the media has
///    to be relayed by TURN. The relay and its credential are configuration, not
///    something to compile into an APK.
///  * **Neither side names itself.** The API reads the party from the bearer
///    token. Both sides used to send the doctor's id as `sender`, so each
///    filtered out the other's offer as its own echo.
///  * **The remote view starts empty.** It used to be pointed at the local
///    camera until a remote track arrived, so a call that never connected looked
///    exactly like one that had — you were watching yourself.
///  * **A hang-up is read off the consultation.** A peer connection notices a
///    clean close but not a phone that lost signal, so the record is the
///    authority on whether the call is still on.
///  * **The audio route is actually set.** `CallSession` defaulted
///    `isSpeakerOn` to true and nothing ever told the platform, so on a voice
///    call the button said "speaker" while the sound came out of the earpiece —
///    and the first tap of it appeared to do nothing, because it was switching
///    *away* from a state the phone had never been in. The route is applied
///    when the stream opens now, and it differs by call type: a video call is
///    held at arm's length and belongs on the speaker, a voice call is held to
///    the ear and does not.
class WebRtcMediaService {
  WebRtcMediaService(this._signalling);

  final CallSignallingClient _signalling;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  Timer? _signalingTimer;

  /// Cursor into the peer's ICE candidates, so each poll asks only for what it
  /// has not seen.
  int _candidateCursor = 0;

  bool _remoteDescriptionSet = false;
  bool _answered = false;

  /// How often the handshake is polled while connecting. A second is brisk
  /// enough that answering feels immediate.
  static const Duration signalInterval = Duration(seconds: 1);

  /// And after media is flowing, when the same poll is only still there to
  /// notice the other side hanging up and to keep the two timers agreeing.
  static const Duration heartbeatInterval = Duration(seconds: 3);

  /// True once media flows, which is what slows the poll down. The poll does
  /// **not** stop: a peer connection notices a clean close, but a phone that
  /// lost signal or was force-quit closes nothing, so the consultation record
  /// stays the authority on whether the call is still on.
  bool _connected = false;

  static const Map<String, dynamic> _configConstraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  Future<void> initRenderers(
    RTCVideoRenderer localRenderer,
    RTCVideoRenderer remoteRenderer,
  ) async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  /// Opens the camera, connects to the peer, and keeps the handshake going.
  ///
  /// [onRemoteEnded] fires when the other side hung up, and [onDuration] each
  /// time the server reports how long the call has run — the timer is anchored
  /// there rather than counted locally, so both phones show the same number.
  Future<void> startSession({
    required CallSession session,
    required RTCVideoRenderer localRenderer,
    required RTCVideoRenderer remoteRenderer,
    required void Function(CallState) onStateChanged,
    void Function()? onRemoteEnded,
    void Function(int seconds)? onDuration,
  }) async {
    final consultationId = session.consultationId;

    if (consultationId == null) {
      // Every real call comes from a brokered consultation, which is what names
      // the room and says who is in it. Without one there is nothing to join.
      throw const Failure(
        'Start the call from a consultation so the doctor can be reached.',
      );
    }

    // Retry lands here with the previous attempt's state still set —
    // `_connected`, the candidate cursor, and the two handshake flags. A
    // second attempt that starts believing it has already answered an offer
    // never answers the new one, so Retry could only ever fail: it looked like
    // the network, and it was the app. Cleared before anything is opened.
    await closeSession(localRenderer, remoteRenderer);

    // Which attempt this is. A hang-up or a closed screen while the call is
    // still opening runs [closeSession], which moves this on — and everything
    // below checks it after each wait, rather than carrying on to open a
    // microphone and a connection for a call nobody is on any more.
    final attempt = _attempt;
    bool abandoned() => attempt != _attempt;

    try {
      final isVideoCall = session.mode == ConsultationMode.video;
      _speakerOn = session.isSpeakerOn;

      // Claimed before the microphone opens, never assumed. The phone's own
      // ringing screen hands the call to Android's telecom service, and that
      // service resets the audio mode to "normal" when its call ends — which it
      // does as this screen opens. In normal mode there is no earpiece route
      // and no echo cancellation, so a voice call went silent or howled while a
      // video call, on the speaker anyway, sounded fine.
      await _claimAudio();

      final stream = await _openCamera(video: isVideoCall);
      if (abandoned()) {
        await _release(stream);
        return;
      }
      _localStream = stream;
      localRenderer.srcObject = _localStream;

      // A microphone muted at the device level stays muted across calls, and
      // the telecom call the doctor answered can leave it that way. The mute
      // button works on the track, so nothing in the app would ever undo it.
      try {
        await Helper.setMicrophoneMuted(false);
      } catch (_) {
        // Not every platform has a device-level mute.
      }

      // Only now, with the microphone actually open. `connecting` is what the
      // call screen starts the call's foreground service on, and Android
      // closes an app whose microphone service starts before the microphone
      // permission has been granted.
      onStateChanged(CallState.connecting);

      // The route, applied rather than assumed. `session.isSpeakerOn` is the
      // state the controls will draw, so telling the platform here is what
      // stops the icon and the sound from disagreeing.
      //
      // Swallowed rather than propagated: a phone that will not switch its
      // audio route still makes a perfectly good call out of whichever output
      // it is already using, and failing the call over it would be absurd.
      try {
        await toggleSpeaker(session.isSpeakerOn);
      } catch (_) {
        // Reported by `toggleSpeaker` itself.
      }

      // Server-supplied. A missing or empty list would leave the connection
      // with no way to discover a route, so the fetch failing is a failed
      // call rather than something to shrug off.
      final iceServers = await _signalling.iceServers();
      if (abandoned()) return;

      final pc = await createPeerConnection({
        'iceServers': iceServers,
        // Both phones are behind NAT and the relay is the point of TURN, so
        // there is no reason to gather host candidates the peer cannot use.
        'sdpSemantics': 'unified-plan',
      }, _configConstraints);
      if (abandoned()) {
        await pc.close();
        return;
      }
      _peerConnection = pc;

      for (final track in stream.getTracks()) {
        await pc.addTrack(track, stream);
      }
      if (abandoned()) return;

      pc.onTrack = (event) {
        if (event.streams.isEmpty) return;

        _remoteStream = event.streams.first;
        try {
          remoteRenderer.srcObject = _remoteStream;
        } catch (error) {
          // The screen closed while the track was on its way.
          debugPrint('Remote renderer gone: $error');
        }

        // Held on this side of the renderer as well. On a voice call the
        // remote renderer is never mounted — the screen draws an avatar
        // instead — and a stream whose only reference was a renderer nothing
        // is showing is a stream that can be collected mid-sentence.
        for (final track in _remoteStream!.getAudioTracks()) {
          track.enabled = true;
        }

        // The remote audio track is what starts the platform's audio routing,
        // and starting it picks a route of its own. Put back the one this call
        // is meant to be on.
        if (event.track.kind == 'audio') unawaited(_reapplyRoute());
      };

      pc.onConnectionState = (state) {
        debugPrint('WebRTC connection state: $state');

        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            // Only now. Reporting `connected` the moment the offer was posted
            // is what made a call that never joined look like one that had.
            onStateChanged(CallState.connected);
            // The handshake is done, so the poll drops to a heartbeat rather
            // than stopping — it is still what tells this phone the other side
            // hung up.
            if (!_connected) {
              _connected = true;
              // Once more now that media flows: anything that touched the
              // audio session during the handshake has finished by now.
              unawaited(_reapplyRoute());
              // Starts the call's clock on the server, so the timer both
              // phones show counts from now — not from when the call screen
              // opened, which included the ringing.
              unawaited(
                _signalling.markConnected(consultationId).catchError(
                  (Object error) =>
                      debugPrint('Could not report connected: $error'),
                ),
              );
              _startSignalling(
                consultationId: consultationId,
                onStateChanged: onStateChanged,
                onRemoteEnded: onRemoteEnded,
                onDuration: onDuration,
              );
            }
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            onStateChanged(CallState.reconnecting);
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            onStateChanged(CallState.failed);
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            onStateChanged(CallState.ended);
          default:
            break;
        }
      };

      pc.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;

        // Fire and forget: a dropped candidate costs one possible route, and
        // failing the call over it would be worse than trying the rest.
        _signalling.sendCandidate(consultationId, candidate.toMap()).catchError(
          (Object error) {
            debugPrint('Candidate not delivered: $error');
          },
        );
      };

      // Exactly one side offers, and the API decided which before either phone
      // got here. Both devices used to ask "has anyone offered yet?" and become
      // the caller if not — a race both could win, after which neither answered.
      if (session.isCaller) {
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        if (abandoned()) return;
        await _signalling.sendOffer(consultationId, offer.toMap());
      }
      if (abandoned()) return;

      _startSignalling(
        consultationId: consultationId,
        onStateChanged: onStateChanged,
        onRemoteEnded: onRemoteEnded,
        onDuration: onDuration,
      );
    } on Failure {
      onStateChanged(CallState.failed);
      rethrow;
    } catch (error) {
      debugPrint('Error starting WebRTC session: $error');
      onStateChanged(CallState.failed);
      rethrow;
    }
  }

  /// Camera and microphone, with the denial turned into something readable.
  ///
  /// A refused permission and a camera in use by another app both surface as the
  /// same opaque platform exception, and "Failed to start call:
  /// PlatformException(...)" tells a doctor nothing they can act on.
  Future<MediaStream> _openCamera({required bool video}) async {
    try {
      return await navigator.mediaDevices.getUserMedia({
        // Asked for by name. A voice call held at arm's length, or on the
        // speaker, feeds the other side's voice straight back into the
        // microphone without them.
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': video
            ? {
                // A request, not a demand. `mandatory` with a minimum frame rate
                // is refused outright by phones that cannot meet it, and a
                // slightly softer picture is better than no call.
                'width': {'ideal': 640},
                'height': {'ideal': 480},
                'frameRate': {'ideal': 24},
                'facingMode': 'user',
              }
            : false,
      });
    } catch (error) {
      debugPrint('getUserMedia failed: $error');

      throw Failure(
        video
            ? 'Allow camera and microphone access to make a video call.'
            : 'Allow microphone access to make a call.',
      );
    }
  }

  /// Polls for the peer's half of the handshake until media is flowing.
  void _startSignalling({
    required String consultationId,
    required void Function(CallState) onStateChanged,
    void Function()? onRemoteEnded,
    void Function(int seconds)? onDuration,
  }) {
    _signalingTimer?.cancel();
    _signalingTimer = Timer.periodic(
      _connected ? heartbeatInterval : signalInterval,
      (_) async {
        final pc = _peerConnection;
        if (pc == null) return;

        try {
          final inbox = await _signalling.poll(
            consultationId,
            after: _candidateCursor,
          );

          _candidateCursor = inbox.nextCandidate;

          // Only once the server counts from the connection. Before that its
          // figure includes the ringing, and the phone counts from 00:00 on
          // its own instead.
          if (inbox.isConnectedOnServer) {
            onDuration?.call(inbox.durationSeconds);
          }

          if (inbox.isOver) {
            // The other side hung up, or the consultation was closed out. Ends
            // here rather than waiting for a peer connection that may never
            // notice — a phone that lost signal closes nothing.
            _signalingTimer?.cancel();
            _signalingTimer = null;
            onRemoteEnded?.call();
            return;
          }

          if (_connected) return;

          await _applyDescription(pc, consultationId, inbox);
          await _applyCandidates(pc, inbox);
        } catch (error) {
          // One failed poll on a patchy connection is not a failed call. The
          // next tick retries; a connection that genuinely cannot be made
          // surfaces through the peer connection's own failed state.
          debugPrint('Signalling poll failed: $error');
        }
      },
    );
  }

  /// Sets the peer's offer or answer, and answers an offer once.
  Future<void> _applyDescription(
    RTCPeerConnection pc,
    String consultationId,
    SignalInbox inbox,
  ) async {
    if (_remoteDescriptionSet || inbox.sdp == null) return;

    final type = inbox.descriptionType;
    if (type == null) return;

    await pc.setRemoteDescription(
      RTCSessionDescription(inbox.sdp!['sdp'] as String?, type),
    );
    _remoteDescriptionSet = true;

    // The callee answers. Retried on every tick until the offer arrives,
    // because the doctor can be in the room before the patient's device has
    // posted one — a callee that looked only once would wait forever.
    if (type == 'offer' && !_answered) {
      _answered = true;

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      await _signalling.sendAnswer(consultationId, answer.toMap());
    }
  }

  /// Adds the peer's candidates.
  ///
  /// Only after a remote description exists: a candidate added before it is
  /// discarded, and the cursor would have moved past it — so they are held
  /// until the description lands rather than lost.
  Future<void> _applyCandidates(RTCPeerConnection pc, SignalInbox inbox) async {
    if (!_remoteDescriptionSet) {
      _pendingCandidates.addAll(inbox.candidates);
      return;
    }

    final candidates = [..._pendingCandidates, ...inbox.candidates];
    _pendingCandidates.clear();

    for (final candidate in candidates) {
      await pc.addCandidate(
        RTCIceCandidate(
          candidate['candidate'] as String?,
          candidate['sdpMid'] as String?,
          (candidate['sdpMLineIndex'] as num?)?.toInt(),
        ),
      );
    }
  }

  final List<Map<String, dynamic>> _pendingCandidates = [];

  Future<void> toggleAudioMute(bool mute) async {
    for (final track in _localStream?.getAudioTracks() ?? const []) {
      track.enabled = !mute;
    }
  }

  Future<void> toggleVideoMute(bool mute) async {
    for (final track in _localStream?.getVideoTracks() ?? const []) {
      track.enabled = !mute;
    }
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? const [];
    if (tracks.isEmpty) return;

    await Helper.switchCamera(tracks.first);
  }

  /// Speaker or earpiece.
  ///
  /// Never throws. Routing is the one call here that depends on what the
  /// platform's audio session is doing at that instant — a headset being
  /// unplugged, or a system call arriving — and a refused route change is a
  /// call that sounds wrong, not a call that should end. The controls revert
  /// to the state that actually took effect.
  Future<void> toggleSpeaker(bool speakerOn) async {
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
      _speakerOn = speakerOn;
    } catch (error) {
      debugPrint('Could not switch the audio route: $error');
      rethrow;
    }
  }

  /// The route the call is meant to be on — what [toggleSpeaker] last set.
  bool _speakerOn = false;

  /// Puts the audio back on [_speakerOn]'s route. Quiet on failure: the call
  /// still plays out of whatever route the phone chose.
  Future<void> _reapplyRoute() async {
    try {
      await Helper.setSpeakerphoneOn(_speakerOn);
    } catch (error) {
      debugPrint('Could not restore the audio route: $error');
    }
  }

  /// A voice call's audio mode, focus and stream on Android.
  ///
  /// Not left to the plugin's defaults, because the defaults only apply when
  /// nothing else has touched the audio session — and the ringing screen's
  /// telecom call has, every time a doctor answers from it.
  Future<void> _claimAudio() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await Helper.setAndroidAudioConfiguration(
        AndroidAudioConfiguration.communication,
      );
    } catch (error) {
      debugPrint('Could not claim the call audio mode: $error');
    }
  }

  /// Moved on by every [closeSession]. See `abandoned` in [startSession].
  int _attempt = 0;

  /// Hands the camera and microphone back.
  Future<void> _release(MediaStream stream) async {
    try {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    } catch (error) {
      debugPrint('Could not release the camera and microphone: $error');
    }
  }

  Future<void> closeSession(
    RTCVideoRenderer localRenderer,
    RTCVideoRenderer remoteRenderer,
  ) async {
    _attempt++;
    _signalingTimer?.cancel();
    _signalingTimer = null;
    _candidateCursor = 0;
    _remoteDescriptionSet = false;
    _answered = false;
    // Was missed, and it is the one that broke Retry: a second attempt started
    // with `_connected` still true, so its handshake poll ran at the 3-second
    // heartbeat interval and its `_applyDescription` returned immediately.
    _connected = false;
    _pendingCandidates.clear();

    // Silenced before closing, so nothing this connection does on its way out
    // — a last state change, a late track — reaches a screen that has gone.
    final pc = _peerConnection;
    _peerConnection = null;
    pc
      ?..onTrack = null
      ..onConnectionState = null
      ..onIceCandidate = null;

    try {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    } catch (_) {
      // Already disposed with the screen.
    }

    final stream = _localStream;
    _localStream = null;
    _remoteStream = null;
    if (stream != null) await _release(stream);

    try {
      await pc?.close();
    } catch (error) {
      debugPrint('Could not close the peer connection: $error');
    }
  }

  Future<void> disposeRenderers(
    RTCVideoRenderer localRenderer,
    RTCVideoRenderer remoteRenderer,
  ) async {
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }
}
