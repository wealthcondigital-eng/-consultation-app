import '../../../consultation/domain/entities/consult_option.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import 'code_name.dart';
import 'consult_language.dart';

/// What the patient filled in on the anonymous booking form.
class AnonymousBooking {
  const AnonymousBooking({
    required this.codeName,
    required this.language,
    this.kind = ConsultOptionKind.instant,
    this.concern,
  });

  final CodeName codeName;

  /// **Always audio.** An anonymous consultation is a voice call, and the form
  /// no longer offers the choice.
  ///
  /// A patient who came here came for privacy, and a video call gives their
  /// face to the doctor — which undoes the alias, the language picker and every
  /// other promise on the screen in one tap. Offering it as one of two equal
  /// options made the most private flow in the app a place where the wrong
  /// choice was one mis-tap away and could not be taken back.
  ///
  /// Kept as a field rather than hard-coded at each call site so the mode still
  /// travels with the booking, and so widening this later is one edit.
  ConsultationMode get mode => ConsultationMode.audio;

  /// Now, or a slot booked for later. Anonymity is a property of the
  /// consultation, not of how soon it happens — a patient who wants to speak to
  /// somebody under an alias on Thursday is asking for the same thing as one
  /// who wants to now.
  final ConsultOptionKind kind;

  final ConsultLanguage language;

  /// The patient's own words on what they want to discuss.
  ///
  /// **Required**, and the one thing on this screen that is. An alias tells the
  /// doctor nothing — no name, no history, no face — so without this they join
  /// a call knowing literally nothing about who they are treating or why. The
  /// concern is the only clinical context an anonymous consultation has, which
  /// makes "optional" the wrong answer: it was the field most likely to be
  /// skipped and the only one the doctor actually needed.
  final String? concern;

  /// Long enough to say something. A one-word answer is not context, and
  /// leaving the bar at "not empty" would let a full stop through.
  static const int minConcernLength = 10;

  /// Why the concern cannot be submitted, or null when it can.
  String? get concernError {
    final written = concern?.trim() ?? '';

    if (written.isEmpty) {
      return 'Tell the doctor what you would like to discuss.';
    }
    if (written.length < minConcernLength) {
      return 'A little more detail helps the doctor prepare.';
    }

    return null;
  }

  bool get isValid => codeName.isValid && concernError == null;

  AnonymousBooking copyWith({
    CodeName? codeName,
    ConsultOptionKind? kind,
    ConsultLanguage? language,
    String? concern,
  }) {
    return AnonymousBooking(
      codeName: codeName ?? this.codeName,
      kind: kind ?? this.kind,
      language: language ?? this.language,
      concern: concern ?? this.concern,
    );
  }
}
