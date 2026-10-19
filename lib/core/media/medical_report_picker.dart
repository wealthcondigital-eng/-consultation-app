import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// Where a report came from.
enum ReportSource {
  /// The camera. What most reports are: a patient holding a printed lab result
  /// under a lamp.
  camera,

  /// The photo library.
  gallery,

  /// The file browser — the only route to a PDF, which is what a lab emails.
  file,
}

/// A report picked off the device, ready to upload.
class PickedReport {
  const PickedReport({
    required this.fileName,
    required this.localPath,
    required this.sizeBytes,
  });

  final String fileName;
  final String localPath;
  final int sizeBytes;
}

/// Gets a medical report off the device.
///
/// Behind an interface for the same reason [ProfilePhotoPicker] is: the camera
/// and the file browser are platform plugins, and a screen calling them
/// directly is a screen no widget test can drive.
abstract interface class MedicalReportPicker {
  /// Returns null when the patient backs out. Not an error — a cancel is a
  /// decision.
  Future<PickedReport?> pick(ReportSource source);
}

class PlatformMedicalReportPicker implements MedicalReportPicker {
  const PlatformMedicalReportPicker();

  /// Larger than an avatar's 1024, and deliberately.
  ///
  /// A report is **read**, not looked at: the thing a doctor needs off a lab
  /// printout is a number in six-point type beside a reference range. Downscale
  /// it to a thousand pixels and the photograph is still recognisably the right
  /// page and no longer says anything.
  static const double _maxDimension = 2400;

  /// High enough that fine print survives the re-encode. JPEG artefacts around
  /// small text are what turn a legible scan into an unreadable one.
  static const int _quality = 90;

  /// What the API accepts, and what the file browser is therefore limited to.
  /// Offering a `.docx` only to have the upload refused is a worse experience
  /// than not offering it.
  static const List<String> _extensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'heic',
    'webp',
  ];

  @override
  Future<PickedReport?> pick(ReportSource source) async {
    return switch (source) {
      ReportSource.camera => _photograph(ImageSource.camera),
      ReportSource.gallery => _photograph(ImageSource.gallery),
      ReportSource.file => _browse(),
    };
  }

  Future<PickedReport?> _photograph(ImageSource source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _quality,
    );

    if (photo == null) return null;

    return PickedReport(
      fileName: _named(photo.name, photo.path),
      localPath: photo.path,
      // Measured rather than reported: the size check before the upload is what
      // stands between a 40 MB scan and a minute of a phone connection.
      sizeBytes: await photo.length(),
    );
  }

  Future<PickedReport?> _browse() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Select a report',
      type: FileType.custom,
      allowedExtensions: _extensions,
    );

    // No path means the platform handed back bytes only, which this upload does
    // not read — treated as a cancel rather than as a silent failure.
    final path = picked?.path;
    if (picked == null || path == null) return null;

    return PickedReport(
      fileName: _named(picked.name, path),
      localPath: path,
      sizeBytes: await picked.xFile.length(),
    );
  }

  /// A name that carries an extension, because the extension is what decides
  /// the content type the upload declares. Falls back to the path's, then to
  /// the JPEG both platforms actually produce after a re-encode.
  static String _named(String name, String path) {
    if (name.contains('.')) return name;

    final fromPath = path.split(RegExp(r'[\\/]')).last;
    if (fromPath.contains('.')) return fromPath;

    return '$name.jpg';
  }
}
