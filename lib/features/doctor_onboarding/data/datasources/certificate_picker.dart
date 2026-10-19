import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/medical_certificate.dart';
import 'certificate_compressor.dart';
import '../../../../core/l10n/tr.dart';

/// Gets a certificate file off the device.
///
/// Behind an interface because the camera and the file browser are platform
/// plugins: called directly from the screen they would make the whole
/// registration flow untestable, since a widget test has neither.
abstract interface class CertificatePicker {
  /// Returns null when the doctor backs out of the picker. Not an error — the
  /// certificate is optional and the form can be filled by hand.
  Future<MedicalCertificate?> pick(CertificateSource source);
}

/// Camera for a scan, the file browser for anything already on the device.
class PlatformCertificatePicker implements CertificatePicker {
  const PlatformCertificatePicker({
    this.compressor = const ImageCertificateCompressor(),
  });

  /// Runs over whatever was picked, before the doctor is shown a size.
  ///
  /// Here rather than in the upload, deliberately. The card names the file and
  /// its size, and the size the doctor reads should be the one that gets sent;
  /// and the 10 MB limit then applies to the compressed bytes, so a
  /// 12-megapixel photo that used to be refused outright now goes through.
  final CertificateCompressor compressor;

  @override
  Future<MedicalCertificate?> pick(CertificateSource source) async {
    final picked = switch (source) {
      CertificateSource.scan => await _photograph(),
      CertificateSource.gallery => await _browse(),
    };

    if (picked == null) return null;

    return compressor.compress(picked);
  }

  Future<MedicalCertificate?> _photograph() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      // A certificate is read, not admired: a smaller file uploads faster on a
      // phone connection and stays perfectly legible. The compressor is the
      // backstop — some Android camera implementations ignore these hints.
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (photo == null) return null;

    return MedicalCertificate(
      // `image_picker` sometimes answers with a cache name that has no
      // extension at all, and the extension is what decides the content type
      // the upload declares. Filled in from the path, or assumed to be the JPEG
      // every camera on both platforms actually produces.
      fileName: _named(photo.name, photo.path),
      source: CertificateSource.scan,
      sizeBytes: await photo.length(),
      localPath: photo.path,
    );
  }

  Future<MedicalCertificate?> _browse() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: tr('Select your medical certificate'),
      type: FileType.custom,
      allowedExtensions: MedicalCertificate.supportedExtensions,
    );

    // No path means the platform handed back bytes only, which this upload path
    // does not read — treated as a cancel rather than a silent failure.
    final path = picked?.path;
    if (picked == null || path == null) return null;

    return MedicalCertificate(
      fileName: _named(picked.name, path),
      source: CertificateSource.gallery,
      // Measured rather than reported: the entity's size check is what stands
      // between a 40MB scan and the upload.
      sizeBytes: await picked.xFile.length(),
      localPath: path,
    );
  }

  /// A name that carries an extension, since [MedicalCertificate.mimeType] is
  /// read off it. Falls back to the path's, then to `.jpg`.
  static String _named(String name, String path) {
    if (_hasExtension(name)) return name;

    final fromPath = path.split(RegExp(r'[/\\]')).last;
    if (_hasExtension(fromPath)) return fromPath;

    return '$name.jpg';
  }

  static bool _hasExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return false;

    return MedicalCertificate.supportedExtensions.contains(
      name.substring(dot + 1).toLowerCase(),
    );
  }
}

/// Hands back a fixed file without touching a plugin.
class FakeCertificatePicker implements CertificatePicker {
  const FakeCertificatePicker();

  @override
  Future<MedicalCertificate?> pick(CertificateSource source) async {
    return MedicalCertificate(
      fileName: source == CertificateSource.scan
          ? 'medical-certificate-scan.pdf'
          : 'medical-certificate.jpg',
      source: source,
      sizeBytes: 1_482_000,
      // No local path: nothing to upload, which is the honest stub. The fake
      // onboarding data source does not read it.
    );
  }
}
