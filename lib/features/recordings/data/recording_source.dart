import 'package:video_player/video_player.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/auth_session.dart';
import '../domain/entities/call_recording.dart';
import 'recording_files.dart';

/// A player for [recording], not yet initialised.
///
/// The phone's own copy when there is one — the patient's, playable offline
/// and free of data — otherwise the server's, streamed with the session's
/// token, since recordings are never public URLs. Used by the full-screen
/// player and the voice-message bubble alike.
Future<VideoPlayerController> recordingPlayer(CallRecording recording) async {
  final local = await const RecordingFiles().localCopy(
    recording.consultationId,
  );
  if (local != null) return VideoPlayerController.file(local);

  return VideoPlayerController.networkUrl(
    Uri.parse('${AppConfig.apiBaseUrl}${recording.streamUrl}'),
    httpHeaders: {
      if (sl<AuthSession>().token case final token?)
        'Authorization': 'Bearer $token',
    },
  );
}
