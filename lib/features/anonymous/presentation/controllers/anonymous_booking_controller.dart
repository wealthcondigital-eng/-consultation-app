import 'package:flutter/foundation.dart';

import '../../../consultation/domain/entities/consult_option.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../domain/entities/anonymous_booking.dart';
import '../../domain/entities/anonymous_session.dart';
import '../../domain/entities/code_name.dart';
import '../../domain/entities/consult_language.dart';

/// Presentation state for the anonymous booking form.
///
/// The alias starts empty: the patient chooses the name a doctor will see.
class AnonymousBookingController extends ChangeNotifier {
  AnonymousBooking _booking = const AnonymousBooking(
    codeName: CodeName(''),
    language: ConsultLanguage.english,
  );
  AnonymousBooking get booking => _booking;

  /// Always audio. There is no control for it any more — see
  /// `AnonymousBooking.mode` for why a video option does not belong on a screen
  /// whose whole promise is that the doctor never learns who you are.
  ConsultationMode get mode => _booking.mode;

  ConsultOptionKind get kind => _booking.kind;
  ConsultLanguage get language => _booking.language;

  /// Held back until the first submit so the field is not red while typing.
  bool _showCodeNameError = false;
  String? get codeNameError =>
      _showCodeNameError ? _booking.codeName.validationError : null;

  /// Same rule for the concern: not red while the patient is still typing it.
  bool _showConcernError = false;
  String? get concernError => _showConcernError ? _booking.concernError : null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void changeKind(ConsultOptionKind value) {
    if (value == _booking.kind) return;
    _booking = _booking.copyWith(kind: value);
    notifyListeners();
  }

  void changeLanguage(ConsultLanguage value) {
    if (value == _booking.language) return;
    _booking = _booking.copyWith(language: value);
    notifyListeners();
  }

  void changeCodeName(String value) {
    _booking = _booking.copyWith(codeName: CodeName(value));
    // Clear a standing error as soon as the entry becomes usable.
    if (_showCodeNameError && _booking.codeName.isValid) {
      _showCodeNameError = false;
    }
    notifyListeners();
  }

  void changeConcern(String value) {
    final concern = value.trim();
    // Rebuilt rather than copied: `copyWith` cannot set a field back to null,
    // and clearing the box has to clear the concern — otherwise the doctor is
    // sent a sentence the patient deleted.
    _booking = AnonymousBooking(
      codeName: _booking.codeName,
      kind: _booking.kind,
      language: _booking.language,
      concern: concern.isEmpty ? null : concern,
    );

    // Clear a standing error the moment the entry becomes usable, the same way
    // the alias field does.
    if (_showConcernError && _booking.concernError == null) {
      _showConcernError = false;
    }
    notifyListeners();
  }

  /// Confirms the booking, or returns null when the form is not usable yet.
  ///
  /// **No network call.** It used to make one — a stub `startSession` that
  /// invented an id, wrote nothing and rang nobody, which is why an anonymous
  /// consultation looked booked and never reached a doctor. The consultation is
  /// filed by matching, on the same endpoint every other instant consultation
  /// uses, with the alias attached; there is nothing to open first.
  AnonymousSession? submit() {
    if (!_booking.isValid) {
      _showCodeNameError = true;
      _showConcernError = true;
      notifyListeners();
      return null;
    }

    _errorMessage = null;
    notifyListeners();

    return AnonymousSession.from(_booking);
  }
}
