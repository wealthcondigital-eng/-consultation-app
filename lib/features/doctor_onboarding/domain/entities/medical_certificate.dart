/// Where the doctor got the file from.
enum CertificateSource {
  /// Photographed with the document scanner.
  scan,

  /// Picked from the device's gallery or files.
  gallery,
}

/// The medical certificate a doctor uploads to prove they can practise.
class MedicalCertificate {
  const MedicalCertificate({
    required this.fileName,
    required this.source,
    required this.sizeBytes,
    this.localPath,
    this.storagePath,
  });

  /// What the upload accepts, stated on the upload card and enforced here.
  static const int maxSizeBytes = 10 * 1024 * 1024;
  static const List<String> supportedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

  final String fileName;
  final CertificateSource source;
  final int sizeBytes;

  /// Where the picked file sits on the device, until it is uploaded.
  ///
  /// Null in a record read back from the backend, where only [storagePath]
  /// remains — the local copy is not ours to assume still exists.
  final String? localPath;

  /// Where the file ended up in storage, once uploaded.
  final String? storagePath;

  /// True when there is a file on disk to send.
  bool get isUploadable => (localPath ?? '').isNotEmpty;

  MedicalCertificate copyWith({
    String? fileName,
    int? sizeBytes,
    String? localPath,
    String? storagePath,
  }) {
    return MedicalCertificate(
      fileName: fileName ?? this.fileName,
      source: source,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      localPath: localPath ?? this.localPath,
      storagePath: storagePath ?? this.storagePath,
    );
  }

  /// Lower-case, without the dot.
  String get extension {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  bool get hasSupportedFormat => supportedExtensions.contains(extension);

  /// The content type the multipart upload declares for this file.
  ///
  /// It has to be sent explicitly. `MultipartFile.fromPath` defaults to
  /// `application/octet-stream`, the API checks that header against a
  /// four-entry allowlist, and octet-stream is not on it — so a perfectly good
  /// scan came back as "Upload a PDF or a photo", which reads like the file
  /// being wrong rather than the header being missing.
  ///
  /// It is also what the review console renders from: `image/*` goes in an
  /// `<img>`, `application/pdf` in an `<iframe>`, and anything else falls back
  /// to a download link the reviewer has to open by hand.
  ///
  /// Derived from the extension rather than stored, because the picker only
  /// ever offers [supportedExtensions] and the compressor rewrites the name
  /// when it changes the format.
  String get mimeType => switch (extension) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    _ => 'application/octet-stream',
  };

  /// True for a photograph or a scan, false for a PDF. What decides whether the
  /// compressor has anything to do — a PDF is already compressed, and
  /// re-encoding one needs a PDF engine rather than an image codec.
  bool get isImage => mimeType.startsWith('image/');

  bool get isWithinSizeLimit => sizeBytes > 0 && sizeBytes <= maxSizeBytes;

  bool get isAcceptable => hasSupportedFormat && isWithinSizeLimit;

  /// Why this file cannot be used, or null when it can.
  String? get rejectionReason {
    if (!hasSupportedFormat) {
      return 'Upload a PDF, JPG or PNG file.';
    }
    if (!isWithinSizeLimit) {
      return 'That file is over the ${maxSizeBytes ~/ (1024 * 1024)}MB limit.';
    }
    return null;
  }

  /// `1.4 MB`
  String get sizeLabel {
    const megabyte = 1024 * 1024;
    if (sizeBytes >= megabyte) {
      return '${(sizeBytes / megabyte).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024).round()} KB';
  }
}
