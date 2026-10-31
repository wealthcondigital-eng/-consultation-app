import '../../../core/network/api_client.dart';
import '../domain/entities/call_recording.dart';

/// Reads the call recordings the signed-in user may play.
abstract interface class RecordingsRemoteDataSource {
  /// Every ready recording the caller is part of, newest first. [withUserId]
  /// narrows it to one patient–doctor pair.
  Future<List<CallRecording>> fetch({String? withUserId});
}

/// `GET /recordings` — as the patient or as the doctor, the server decides.
class ApiRecordingsRemoteDataSource implements RecordingsRemoteDataSource {
  ApiRecordingsRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  Future<List<CallRecording>> fetch({String? withUserId}) async {
    final query = withUserId == null
        ? ''
        : '?with=${Uri.encodeQueryComponent(withUserId)}';
    final body = await _client.get('/recordings$query');

    final rows = body['recordings'];
    if (rows is! List) return const [];

    return [
      for (final row in rows.whereType<Map<String, Object?>>()) ?_parse(row),
    ];
  }

  static CallRecording? _parse(Map<String, Object?> row) {
    final id = row['id'];
    final consultationId = row['consultationId'];
    final streamUrl = row['streamUrl'];
    if (id is! String || consultationId is! String || streamUrl is! String) {
      return null;
    }

    final doctor = row['doctor'] is Map ? row['doctor']! as Map : const {};
    final patient = row['patient'] is Map ? row['patient']! as Map : const {};

    return CallRecording(
      id: id,
      consultationId: consultationId,
      isVideo: row['mode'] != 'audio',
      duration: Duration(
        seconds: (row['durationSeconds'] as num?)?.round() ?? 0,
      ),
      sizeBytes: (row['sizeBytes'] as num?)?.toInt() ?? 0,
      mimeType: row['mimeType'] as String? ?? 'video/mp4',
      recordedAt:
          DateTime.tryParse(row['recordedAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      streamUrl: streamUrl,
      doctorUserId: doctor['userId'] as String? ?? '',
      doctorName: doctor['name'] as String? ?? 'Doctor',
      doctorPhotoUrl: doctor['photoUrl'] as String?,
      patientUserId: patient['userId'] as String? ?? '',
      patientName: patient['name'] as String? ?? 'Patient',
      transcript: _transcript(row['transcript']),
    );
  }

  /// `{status, text, language, segments: [{start, end, text}]}`. An older
  /// server sends nothing, which reads as "No transcript available".
  static RecordingTranscript _transcript(Object? value) {
    if (value is! Map) return const RecordingTranscript.none();

    Duration seconds(Object? raw) =>
        Duration(milliseconds: ((raw as num?) ?? 0).toDouble() * 1000 ~/ 1);

    final segments = value['segments'];
    return RecordingTranscript(
      status: TranscriptStatus.from(value['status'] as String?),
      text: (value['text'] as String? ?? '').trim(),
      language: value['language'] as String?,
      segments: [
        if (segments is List)
          for (final segment in segments.whereType<Map>())
            if ((segment['text'] as String? ?? '').trim().isNotEmpty)
              TranscriptSegment(
                start: seconds(segment['start']),
                end: seconds(segment['end']),
                text: (segment['text'] as String).trim(),
              ),
      ],
    );
  }
}

/// Offline builds and widget tests: nobody has recorded anything.
class FakeRecordingsRemoteDataSource implements RecordingsRemoteDataSource {
  const FakeRecordingsRemoteDataSource();

  @override
  Future<List<CallRecording>> fetch({String? withUserId}) async => const [];
}
