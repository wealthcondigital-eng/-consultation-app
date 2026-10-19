import '../entities/medical_report.dart';
import '../repositories/profile_repository.dart';

/// The documents on a patient's record: read them, add one, take one away.
///
/// One use case for three operations because they are one feature — a screen
/// that lists reports is always the screen that adds and removes them, and
/// three classes would be three constructor arguments saying the same thing.
class ManageMedicalReports {
  const ManageMedicalReports(this._repository);

  final ProfileRepository _repository;

  /// How large a report may be, matching `DocumentStorageService.maxBytes` on
  /// the API. Checked here so a 15 MB photograph is refused before it is
  /// uploaded rather than after — on a phone connection that is the difference
  /// between an instant message and a minute of waiting for a rejection.
  static const int maxBytes = 10 * 1024 * 1024;

  /// What the API accepts. A patient photographing a printout gets a JPEG; one
  /// forwarding a lab's email gets a PDF.
  static const List<String> allowedExtensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'heic',
    'webp',
  ];

  Future<List<MedicalReport>> load() => _repository.fetchReports();

  Future<MedicalReport> add({
    required String filePath,
    required String title,
    MedicalRecordKind kind = MedicalRecordKind.report,
  }) {
    return _repository.uploadReport(
      filePath: filePath,
      title: title,
      kind: kind,
    );
  }

  Future<void> remove(MedicalReport report) =>
      _repository.deleteReport(report.id);
}
