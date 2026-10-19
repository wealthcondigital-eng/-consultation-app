import 'package:image_picker/image_picker.dart';

/// Where a profile photo came from.
enum PhotoSource { camera, gallery }

/// A photo picked off the device, ready to upload.
class PickedPhoto {
  const PickedPhoto({
    required this.fileName,
    required this.localPath,
    required this.sizeBytes,
  });

  final String fileName;
  final String localPath;
  final int sizeBytes;
}

/// Gets a profile photo off the device.
///
/// Behind an interface for the same reason `CertificatePicker` is: the camera
/// and the gallery are platform plugins, and a screen calling them directly is
/// a screen no widget test can drive.
///
/// In `core/media` rather than under one feature, because both roles have a
/// photo — the patient's profile and the doctor's — and the second copy of a
/// plugin wrapper is the one that drifts from the first.
abstract interface class ProfilePhotoPicker {
  /// Returns null when the person backs out of the picker. Not an error: a
  /// photo is optional, and a cancel is a decision.
  Future<PickedPhoto?> pick(PhotoSource source);
}

class PlatformProfilePhotoPicker implements ProfilePhotoPicker {
  const PlatformProfilePhotoPicker();

  /// An avatar is rendered at a hundred logical pixels at most, so the
  /// full-resolution original is between forty and eighty times more data than
  /// anything on screen can use. Downscaled at the source rather than after the
  /// fact: the bytes never enter the process, which is what keeps a
  /// twelve-megapixel photo from being decoded on the UI isolate.
  ///
  /// 1024 rather than 256, so the same file still looks right on a tablet and
  /// if a larger avatar ever appears.
  static const double _maxDimension = 1024;

  /// Re-encoded at 85, which is where JPEG stops being distinguishable from the
  /// original at this size and the file is a fraction of it.
  static const int _quality = 85;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final picked = await ImagePicker().pickImage(
      source: switch (source) {
        PhotoSource.camera => ImageSource.camera,
        PhotoSource.gallery => ImageSource.gallery,
      },
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _quality,
    );

    if (picked == null) return null;

    return PickedPhoto(
      // `image_picker` sometimes answers with a cache name carrying no
      // extension, and the extension is what decides the content type the
      // upload declares. Filled in from the path, then assumed to be the JPEG
      // that both platforms actually produce after a re-encode.
      fileName: _named(picked.name, picked.path),
      localPath: picked.path,
      sizeBytes: await picked.length(),
    );
  }

  static String _named(String name, String path) {
    if (_hasImageExtension(name)) return name;

    final fromPath = path.split(RegExp(r'[/\\]')).last;
    if (_hasImageExtension(fromPath)) return fromPath;

    return 'profile-photo.jpg';
  }

  static bool _hasImageExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return false;

    return const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
    }.contains(name.substring(dot + 1).toLowerCase());
  }
}

/// Hands back a fixed file without touching a plugin.
class FakeProfilePhotoPicker implements ProfilePhotoPicker {
  const FakeProfilePhotoPicker();

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    return const PickedPhoto(
      fileName: 'profile-photo.jpg',
      // No real file behind it. The fake profile data source does not open the
      // path — it only records that a photo was chosen.
      localPath: 'profile-photo.jpg',
      sizeBytes: 184_000,
    );
  }
}
