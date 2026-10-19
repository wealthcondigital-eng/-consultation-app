import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/answer_consultations.dart';

/// Presentation state for the post-consultation review.
///
/// The screen used to hold all of this itself and end at a `TODO`: the stars
/// were drawn, the chips were tapped, Submit went home, and nothing was ever
/// written. Every review a patient left was discarded, which is why no doctor's
/// profile had one.
class ConsultationFeedbackController extends ChangeNotifier {
  ConsultationFeedbackController(this._consultations);

  final ManageConsultationCall _consultations;

  /// The chips offered under "How was your experience?".
  ///
  /// The app's own list rather than the server's: they are wording, and a code
  /// table on the API would be a second place to change every time one is
  /// reworded. They travel as the labels themselves.
  static const List<String> experiences = [
    'Very Helpful',
    'Good Listener',
    'Professional',
    'Knowledgeable',
    'Friendly',
  ];

  int _doctorRating = 0;
  int get doctorRating => _doctorRating;

  int _callQuality = 0;
  int get callQuality => _callQuality;

  final Set<String> _selected = {};
  Set<String> get selectedExperiences => Set.unmodifiable(_selected);

  String _note = '';

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// A review with no stars is not a review. The note and the chips are
  /// optional; the rating is the thing being asked for.
  bool get canSubmit => _doctorRating > 0 && !_isSubmitting;

  void rateDoctor(int value) {
    if (value == _doctorRating) return;
    _doctorRating = value;
    _errorMessage = null;
    notifyListeners();
  }

  void rateCallQuality(int value) {
    if (value == _callQuality) return;
    _callQuality = value;
    notifyListeners();
  }

  void toggleExperience(String value) {
    if (!_selected.remove(value)) _selected.add(value);
    notifyListeners();
  }

  bool isSelected(String value) => _selected.contains(value);

  /// No control depends on the note, so there is nothing to rebuild.
  void changeNote(String value) => _note = value;

  /// Returns true once the review is stored.
  ///
  /// A failure is reported and the screen stays put. Sending the patient home
  /// on an error would lose what they wrote with nothing said, and this is the
  /// only moment they will ever be willing to write it.
  Future<bool> submit(String consultationId) async {
    if (!canSubmit) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _consultations.rate(
        consultationId,
        rating: _doctorRating,
        feedback: _note.trim().isEmpty ? null : _note.trim(),
        // Zero means "not answered". Sent as null rather than as a one-star
        // connection, which is a different claim entirely.
        callQuality: _callQuality > 0 ? _callQuality : null,
        tags: _selected.toList(),
      );
      return true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      return false;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
