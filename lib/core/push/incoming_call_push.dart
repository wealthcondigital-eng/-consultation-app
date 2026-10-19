import '../../features/consultation/domain/entities/consultation_mode.dart';

/// An incoming consultation, as it arrives in a push message.
///
/// Self-contained on purpose. The message can land on a phone whose app is not
/// running and has no session in memory, so everything the ringing screen shows
/// is in here — a notification that has to sign in and fetch before it can name
/// the caller is one that rings for a stranger for two seconds first.
class IncomingCallPush {
  const IncomingCallPush({
    required this.consultationId,
    required this.channelId,
    required this.mode,
    required this.callerName,
    required this.ringSeconds,
    this.concern,
  });

  final String consultationId;
  final String channelId;
  final ConsultationMode mode;

  /// The patient's name, or their alias on an anonymous consultation.
  final String callerName;

  /// What they wrote on the way in. The doctor decides whether to answer, and
  /// this is most of that decision.
  final String? concern;

  /// How long the caller waits. The handset stops ringing when it runs out,
  /// rather than buzzing in a pocket after the patient has given up.
  final int ringSeconds;

  Duration get ringFor => Duration(seconds: ringSeconds);

  /// Reads one out of an FCM data payload, or null when it is not a call.
  ///
  /// Every value arrives as a string — FCM data payloads have no types — so
  /// each one is parsed rather than cast, and anything missing makes the whole
  /// thing null. A half-read call is worse than none: it would ring with a
  /// blank name and no way to answer.
  static IncomingCallPush? tryParse(Map<String, dynamic> data) {
    if (data['type'] != 'incoming_call') return null;

    final consultationId = data['consultationId'] as String?;
    final channelId = data['channelId'] as String?;
    if (consultationId == null || channelId == null) return null;
    if (consultationId.isEmpty || channelId.isEmpty) return null;

    final concern = (data['concern'] as String?)?.trim();

    return IncomingCallPush(
      consultationId: consultationId,
      channelId: channelId,
      // Video is the safer default for an unreadable mode: it opens the audio
      // controls too, where audio-only would drop a video call to voice.
      mode: data['mode'] == 'audio'
          ? ConsultationMode.audio
          : ConsultationMode.video,
      callerName: (data['callerName'] as String?)?.trim().isNotEmpty == true
          ? (data['callerName'] as String).trim()
          : 'A patient',
      concern: concern == null || concern.isEmpty ? null : concern,
      // A ring that never times out is worse than one that stops early, so an
      // unreadable value falls back to the same 45 seconds the server uses.
      ringSeconds: int.tryParse(data['ringSeconds'] as String? ?? '') ?? 45,
    );
  }

  /// `Video consultation` — what the notification is titled.
  String get modeLabel => switch (mode) {
    ConsultationMode.video => 'Video consultation',
    ConsultationMode.audio => 'Audio consultation',
  };
}
