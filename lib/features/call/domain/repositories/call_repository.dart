import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../entities/call_session.dart';

/// Contract for WebRTC call operations and media stream management.
abstract class CallRepository {
  Future<void> initializeRenderers(
    RTCVideoRenderer localRenderer,
    RTCVideoRenderer remoteRenderer,
  );

  /// Opens the call and keeps it going.
  ///
  /// Reports through callbacks rather than answering with a finished session:
  /// connecting two phones takes several seconds of handshake, so the state a
  /// return value could carry would only ever be `connecting`.
  ///
  /// [onRemoteEnded] fires when the other side hangs up — read off the
  /// consultation, because a phone that lost signal closes no peer connection.
  /// [onDuration] carries the server's count of how long the call has run, so
  /// both phones show the same number.
  Future<void> startCall(
    CallSession session, {
    required void Function(CallState state) onStateChanged,
    void Function()? onRemoteEnded,
    void Function(int seconds)? onDuration,
  });

  Future<void> toggleAudioMute(bool mute);

  Future<void> toggleVideoMute(bool mute);

  Future<void> switchCamera();

  Future<void> toggleSpeaker(bool speakerOn);

  Future<void> endCall();

  Future<void> disposeRenderers(
    RTCVideoRenderer localRenderer,
    RTCVideoRenderer remoteRenderer,
  );
}
