import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What [RecordingComposer.compose] made, or why it made nothing.
@immutable
class ComposeResult {
  const ComposeResult.success({required this.sizeBytes, required this.durationMs})
    : ok = true,
      error = null;

  const ComposeResult.failure(this.error)
    : ok = false,
      sizeBytes = 0,
      durationMs = 0;

  final bool ok;
  final int sizeBytes;
  final int durationMs;
  final String? error;
}

/// Mixes and shrinks a recorded consultation on the phone — Media3
/// Transformer, through `RecordingComposer.kt`.
///
/// The phone records the two sides of the call as two files (see
/// `CallRecorder`), each encoded for live capture rather than for size. This
/// turns them into one file with both voices mixed, the picture scaled to
/// [maxHeight] and re-encoded at a bitrate a patient's data plan can carry —
/// roughly a fifth of the raw size.
///
/// Android only. Elsewhere it reports failure and the caller keeps the raw
/// file, which is the same thing it does when the phone's encoder refuses.
class RecordingComposer {
  const RecordingComposer();

  static const MethodChannel _channel = MethodChannel('consult/recording');

  /// [inputs] are mixed, not concatenated: one Media3 sequence each, played
  /// together. The first is the one whose picture is kept when [hasVideo].
  Future<ComposeResult> compose({
    required List<String> inputs,
    required bool hasVideo,
    required String output,
    int maxHeight = 360,
    int videoBitrate = 600000,
    int audioBitrate = 64000,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const ComposeResult.failure('Not supported on this platform');
    }

    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'compose',
        {
          'inputs': inputs,
          'hasVideo': hasVideo,
          'output': output,
          'maxHeight': maxHeight,
          'videoBitrate': videoBitrate,
          'audioBitrate': audioBitrate,
        },
      );

      if (result == null || result['ok'] != true) {
        return ComposeResult.failure(
          result?['error'] as String? ?? 'Compose failed',
        );
      }

      return ComposeResult.success(
        sizeBytes: (result['sizeBytes'] as num?)?.toInt() ?? 0,
        durationMs: (result['durationMs'] as num?)?.toInt() ?? 0,
      );
    } on PlatformException catch (error) {
      return ComposeResult.failure(error.message ?? error.code);
    } on MissingPluginException {
      return const ComposeResult.failure('Composer not available');
    }
  }
}
