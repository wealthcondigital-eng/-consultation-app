/// One recorded consultation call, as both the patient and the doctor see it.
///
/// Recorded on the patient's phone (with their consent), compressed there, and
/// uploaded; this is the server's record of it. The patient's phone also keeps
/// its own copy, which [RecordingFiles] finds by [consultationId].
class CallRecording {
  const CallRecording({
    required this.id,
    required this.consultationId,
    required this.isVideo,
    required this.duration,
    required this.sizeBytes,
    required this.mimeType,
    required this.recordedAt,
    required this.streamUrl,
    required this.doctorUserId,
    required this.doctorName,
    required this.patientUserId,
    required this.patientName,
    this.doctorPhotoUrl,
    this.transcript = const RecordingTranscript.none(),
  });

  final String id;
  final String consultationId;

  /// A video call; false for an audio call.
  final bool isVideo;

  final Duration duration;
  final int sizeBytes;
  final String mimeType;
  final DateTime recordedAt;

  /// A path on the API, e.g. `/recordings/<id>/stream`. Behind the bearer
  /// token, like every other file the API serves.
  final String streamUrl;

  final String doctorUserId;
  final String doctorName;
  final String? doctorPhotoUrl;
  final String patientUserId;
  final String patientName;

  /// What was said, written out by the server after the upload. See
  /// [RecordingTranscript].
  final RecordingTranscript transcript;

  /// The other person in the consultation, seen from [viewerUserId].
  RecordingParty counterpartOf(String? viewerUserId) =>
      viewerUserId == doctorUserId
      ? RecordingParty(userId: patientUserId, name: patientName)
      : RecordingParty(
          userId: doctorUserId,
          name: doctorName,
          photoUrl: doctorPhotoUrl,
        );

  /// `12:04`, or `1:02:30` past the hour.
  String get durationLabel {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
        : '$minutes:$seconds';
  }

  /// `18.4 MB`.
  String get sizeLabel {
    final mb = sizeBytes / (1024 * 1024);
    return mb >= 1
        ? '${mb.toStringAsFixed(1)} MB'
        : '${(sizeBytes / 1024).ceil()} KB';
  }
}

/// Who a recording thread is with.
class RecordingParty {
  const RecordingParty({
    required this.userId,
    required this.name,
    this.photoUrl,
  });

  final String userId;
  final String name;
  final String? photoUrl;
}

/// Every recording with one counterpart: one "chat" in the list.
class RecordingThread {
  const RecordingThread({required this.counterpart, required this.recordings});

  final RecordingParty counterpart;

  /// Newest first.
  final List<CallRecording> recordings;

  CallRecording get latest => recordings.first;
}

/// Where a recording's transcript has got to.
enum TranscriptStatus {
  /// Queued or being written — worth saying it is on its way.
  preparing,

  /// Written. [RecordingTranscript.text] may still be empty if nothing
  /// intelligible was said.
  ready,

  /// Will not be written: transcription is off, or it failed for good.
  unavailable;

  static TranscriptStatus from(String? value) => switch (value) {
    'pending' || 'processing' => preparing,
    'ready' => ready,
    // 'failed' included: the server has already retried by the time a row
    // says so, and "being prepared" forever would be a promise it can't keep.
    _ => unavailable,
  };
}

/// One stretch of the transcript, with when in the call it was said.
class TranscriptSegment {
  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

/// The written-out call, as the server's speech-to-text produced it.
class RecordingTranscript {
  const RecordingTranscript({
    required this.status,
    this.text = '',
    this.language,
    this.segments = const [],
  });

  const RecordingTranscript.none()
    : status = TranscriptStatus.unavailable,
      text = '',
      language = null,
      segments = const [];

  final TranscriptStatus status;
  final String text;

  /// The language the server heard, e.g. `hindi` or `english`.
  final String? language;

  final List<TranscriptSegment> segments;

  /// Something to show — anything else reads "No transcript available".
  bool get hasText =>
      status == TranscriptStatus.ready && text.trim().isNotEmpty;
}
