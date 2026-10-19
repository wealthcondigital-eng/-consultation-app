import '../../../../core/error/failure.dart';
import '../entities/medical_history.dart';
import '../repositories/profile_repository.dart';

/// The patient's medical record: read it, and replace it.
///
/// One use case for both halves rather than two, because the screen does both
/// and there is no caller that wants only one — the same shape
/// `ManageAvailability` and `ManagePracticeSetup` already take on the doctor's
/// side.
class ManageMedicalHistory {
  const ManageMedicalHistory(this._repository);

  final ProfileRepository _repository;

  /// The stored record, or the empty one for a patient who has recorded
  /// nothing. Never throws for absence — a blank record is a blank form, not an
  /// error.
  Future<MedicalHistory> load() => _repository.fetchMedicalHistory();

  /// Replaces it, and answers with what was actually stored.
  ///
  /// The list caps are the API's, restated here so a patient who has pasted a
  /// hundred lines is told at the form rather than after a round trip. Sixty
  /// characters short of the server's own limit is deliberate: the two should
  /// not disagree by one and leave a value the app accepts and the API refuses.
  Future<MedicalHistory> save(MedicalHistory history) {
    if (_tooLong(history)) {
      throw const Failure(
        'That is more entries than we can store. Remove a few and try again.',
      );
    }

    return _repository.saveMedicalHistory(history);
  }

  /// Matches `SaveMedicalHistoryDto`'s `@ArrayMaxSize(40)`.
  static const int maxEntriesPerSection = 40;

  /// Matches its `@MaxLength(2000)` on the notes.
  static const int maxNotesLength = 2000;

  static bool _tooLong(MedicalHistory history) {
    final sections = [
      history.conditions,
      history.medications,
      history.allergies,
      history.surgeries,
    ];

    if (sections.any((section) => section.length > maxEntriesPerSection)) {
      return true;
    }

    return (history.notes?.length ?? 0) > maxNotesLength;
  }
}
