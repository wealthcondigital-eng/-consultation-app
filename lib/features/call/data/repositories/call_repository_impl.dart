import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../domain/entities/call_session.dart';
import '../../domain/repositories/call_repository.dart';
import '../datasources/webrtc_media_service.dart';

class CallRepositoryImpl implements CallRepository {
  CallRepositoryImpl(this._mediaService);

  final WebRtcMediaService _mediaService;

  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  @override
  Future<void> initializeRenderers(
    RTCVideoRenderer localRenderer,
    RTCVideoRenderer remoteRenderer,
  ) async {
    _localRenderer = localRenderer;
    _remoteRenderer = remoteRenderer;
    await _mediaService.initRenderers(localRenderer, remoteRenderer);
  }

  @override
  Future<void> startCall(
    CallSession session, {
    required void Function(CallState state) onStateChanged,
    void Function()? onRemoteEnded,
    void Function(int seconds)? onDuration,
  }) async {
    if (_localRenderer == null || _remoteRenderer == null) {
      throw StateError('Renderers must be initialized before starting call');
    }

    await _mediaService.startSession(
      session: session,
      localRenderer: _localRenderer!,
      remoteRenderer: _remoteRenderer!,
      onStateChanged: onStateChanged,
      onRemoteEnded: onRemoteEnded,
      onDuration: onDuration,
    );
  }

  @override
  Future<void> toggleAudioMute(bool mute) async {
    await _mediaService.toggleAudioMute(mute);
  }

  @override
  Future<void> toggleVideoMute(bool mute) async {
    await _mediaService.toggleVideoMute(mute);
  }

  @override
  Future<void> switchCamera() async {
    await _mediaService.switchCamera();
  }

  @override
  Future<void> toggleSpeaker(bool speakerOn) async {
    await _mediaService.toggleSpeaker(speakerOn);
  }

  @override
  Future<void> endCall() async {
    if (_localRenderer != null && _remoteRenderer != null) {
      await _mediaService.closeSession(_localRenderer!, _remoteRenderer!);
    }
  }

  @override
  Future<void> disposeRenderers(
    RTCVideoRenderer localRenderer,
    RTCVideoRenderer remoteRenderer,
  ) async {
    await _mediaService.disposeRenderers(localRenderer, remoteRenderer);
    _localRenderer = null;
    _remoteRenderer = null;
  }
}
