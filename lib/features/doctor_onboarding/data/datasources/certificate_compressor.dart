import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../../../core/logging/auth_logger.dart';
import '../../domain/entities/medical_certificate.dart';

/// Shrinks a picked certificate before it is uploaded.
///
/// A phone camera hands back 4–8 MB for a sheet of A4, and none of that detail
/// survives being read by a reviewer: the file is a document, not a photograph.
/// Re-encoding it at a legible size is the difference between an upload that
/// finishes on a 3G connection and one that times out, and between a review
/// queue that costs megabytes per applicant and one that costs kilobytes.
///
/// Behind an interface for the same reason the picker is: the fake
/// implementation lets the onboarding flow be tested without an image codec.
abstract interface class CertificateCompressor {
  /// Returns the certificate to upload — a smaller one where that was possible,
  /// and the original otherwise.
  ///
  /// Never throws. A file this cannot re-encode is still a file the doctor
  /// chose, and refusing the upload because the optimisation failed would trade
  /// a working registration for a smaller one.
  Future<MedicalCertificate> compress(MedicalCertificate certificate);
}

/// Downscales and re-encodes images; passes PDFs straight through.
///
/// A PDF is left alone deliberately. Its images are already JPEG-compressed
/// inside the container, so a second pass gains little, and doing it properly
/// means embedding a PDF engine to take the file apart and put it back
/// together — a large dependency in exchange for a few per cent.
class ImageCertificateCompressor implements CertificateCompressor {
  const ImageCertificateCompressor();

  /// The long edge of the stored image, in pixels.
  ///
  /// 2000px across A4 is about 170 dpi, which is comfortably enough to read a
  /// council registration number and a signature. The camera path already asks
  /// `image_picker` for this; the gallery path had no equivalent, which is how
  /// a 12-megapixel photo reached the server untouched.
  static const int maxEdge = 2000;

  /// JPEG quality. 80 is where text on a white ground stops showing ringing
  /// around the glyphs; below that a scan starts to look like a fax.
  static const int quality = 80;

  /// Below this saving the original is kept.
  ///
  /// Re-encoding always costs *something* — a generation of JPEG loss, and a
  /// second copy in the cache directory. Worth it for the megabytes a camera
  /// produces, not for a 300 KB scan that would come out 280 KB.
  static const int minimumSaving = 64 * 1024;

  @override
  Future<MedicalCertificate> compress(MedicalCertificate certificate) async {
    final path = certificate.localPath;

    // Nothing on disk, or a PDF: there is nothing this can usefully do.
    if (path == null || path.isEmpty || !certificate.isImage) {
      return certificate;
    }

    try {
      final original = await File(path).readAsBytes();

      // In an isolate. Decoding 12 megapixels in Dart takes long enough to drop
      // frames, and the doctor is looking at the form while it happens.
      final shrunk = await compute(
        _reencode,
        _Request(bytes: original, maxEdge: maxEdge, quality: quality),
      );

      if (shrunk == null) {
        AuthLogger.event('certificate · not an image this codec reads', {
          'name': certificate.fileName,
        });
        return certificate;
      }

      final saved = original.length - shrunk.length;
      if (saved < minimumSaving) {
        // Includes the case where JPEG came out *larger*, which happens with a
        // flat PNG screenshot of a certificate.
        AuthLogger.event('certificate · kept the original', {
          'name': certificate.fileName,
          'saving': '$saved bytes',
        });
        return certificate;
      }

      final target = await _write(path, shrunk);
      if (target == null) return certificate;

      AuthLogger.event('certificate · compressed', {
        'name': certificate.fileName,
        'from': _mb(original.length),
        'to': _mb(shrunk.length),
      });

      // The name changes with the format. An `.png` holding JPEG bytes would
      // make [MedicalCertificate.mimeType] lie, and that value is both what the
      // API checks its allowlist against and what the console picks a viewer
      // with — so the extension has to follow the encoder.
      return certificate.copyWith(
        fileName: _jpegName(certificate.fileName),
        sizeBytes: shrunk.length,
        localPath: target.path,
      );
    } on Object catch (error) {
      // Out of memory on a very large image, an unreadable file, a full cache
      // directory. All of them mean "upload what the doctor picked".
      AuthLogger.event('certificate · compression skipped', {
        'name': certificate.fileName,
        'error': '$error',
      });
      return certificate;
    }
  }

  /// Writes beside the picked file, which is the app's own cache directory.
  ///
  /// Both pickers copy what they hand back into the app cache before returning
  /// a path, so the parent is writable and gets cleared by the platform like
  /// any other cache. `Directory.systemTemp` is the fallback rather than the
  /// first choice: on Android it depends on `TMPDIR` being set for the process.
  Future<File?> _write(String sourcePath, Uint8List bytes) async {
    final name = '${_stem(sourcePath)}-compressed.jpg';

    for (final candidate in [
      File('${File(sourcePath).parent.path}${Platform.pathSeparator}$name'),
      File('${Directory.systemTemp.path}${Platform.pathSeparator}$name'),
    ]) {
      try {
        await candidate.writeAsBytes(bytes, flush: true);
        return candidate;
      } on FileSystemException {
        continue;
      }
    }

    return null;
  }

  static String _stem(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  static String _jpegName(String fileName) => '${_stem(fileName)}.jpg';

  static String _mb(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

/// What crosses into the isolate. Plain fields, because a closure would not.
class _Request {
  const _Request({
    required this.bytes,
    required this.maxEdge,
    required this.quality,
  });

  final Uint8List bytes;
  final int maxEdge;
  final int quality;
}

/// Runs in an isolate. Top-level on purpose — `compute` cannot send a method.
///
/// Null when the bytes are not an image format this codec reads, which the
/// caller treats as "upload the original" rather than as an error.
Uint8List? _reencode(_Request request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return null;

  // EXIF orientation has to be baked into the pixels, because the JPEG this
  // writes carries no EXIF of its own. Skipping it is how a portrait photo
  // arrives in the console lying on its side — and a reviewer who has to tilt
  // their head reads that as a broken upload. `copyResize` does this for
  // itself; an image already small enough to skip the resize does not.
  final upright = decoded.exif.imageIfd.hasOrientation
      ? img.bakeOrientation(decoded)
      : decoded;

  final longEdge = upright.width > upright.height
      ? upright.width
      : upright.height;

  final sized = longEdge <= request.maxEdge
      ? upright
      : img.copyResize(
          upright,
          // Exactly one of the two, so the aspect ratio is kept.
          width: upright.width >= upright.height ? request.maxEdge : null,
          height: upright.height > upright.width ? request.maxEdge : null,
          interpolation: img.Interpolation.average,
        );

  return img.encodeJpg(sized, quality: request.quality);
}

/// Hands back whatever it is given.
///
/// Used by the fake backend and by tests: compression is an optimisation, so
/// "did nothing" is a valid implementation of it and needs no image codec.
class PassthroughCertificateCompressor implements CertificateCompressor {
  const PassthroughCertificateCompressor();

  @override
  Future<MedicalCertificate> compress(MedicalCertificate certificate) async =>
      certificate;
}
