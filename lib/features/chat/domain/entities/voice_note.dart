/// A recorded audio clip attached to a chat message.
class VoiceNote {
  const VoiceNote({
    required this.id,
    required this.duration,
    required this.waveform,
    this.url,
    this.transcript,
  });

  final String id;

  final Duration duration;

  /// Amplitude per bar, each between 0 and 1. Pre-computed by whoever recorded
  /// the clip so the bars can be drawn without decoding the audio.
  final List<double> waveform;

  /// Where the audio lives. Null for a clip that has not finished uploading.
  final String? url;

  /// Machine transcription, when the service produced one.
  final String? transcript;

  /// `4:12` — minutes and seconds, which is the whole range a note spans.
  String get durationLabel => formatPosition(duration);

  /// How far through the clip [position] is, as a 0–1 fraction.
  double progressAt(Duration position) {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// `0:07` — used for both the clip length and the playback position.
  static String formatPosition(Duration value) {
    final minutes = value.inMinutes;
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
