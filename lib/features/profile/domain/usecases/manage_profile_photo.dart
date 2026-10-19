import '../repositories/profile_repository.dart';

/// The profile photo: replace it, or take it away.
class ManageProfilePhoto {
  const ManageProfilePhoto(this._repository);

  final ProfileRepository _repository;

  /// Answers with the path the photo is served from, for the account to hold.
  Future<String?> upload(String filePath) => _repository.uploadPhoto(filePath);

  Future<String?> remove() => _repository.removePhoto();
}
