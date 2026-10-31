import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The patient's own copy of a recording, kept on the phone after upload.
///
/// The recorder saves the compressed call as `recordings/<consultationId>.mp4`
/// (video) or `.m4a` (audio) in the app's documents folder. Playing that copy
/// works offline and costs no data, so the player prefers it; the doctor's
/// phone, and a patient who reinstalled, stream from the server instead.
class RecordingFiles {
  const RecordingFiles();

  Future<File?> localCopy(String consultationId) async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      for (final extension in const ['mp4', 'm4a']) {
        final file = File(
          '${documents.path}/recordings/$consultationId.$extension',
        );
        if (await file.exists() && await file.length() > 0) return file;
      }
    } catch (_) {
      // No documents folder (tests, an odd device): stream instead.
    }
    return null;
  }
}
