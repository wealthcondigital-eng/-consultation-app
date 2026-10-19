import '../../../consultation/domain/entities/consult_option.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import 'anonymous_booking.dart';
import 'code_name.dart';
import 'consult_language.dart';

/// A booking the patient has confirmed, carried through the rest of the flow.
///
/// **Not a backend record.** It used to be one: the form called
/// `POST`-shaped `startSession`, which was a stub that handed back
/// `anon-<timestamp>` and wrote nothing anywhere — so an "anonymous
/// consultation" was a local object that no doctor could ever be rung for, and
/// the alias never reached the API at all.
///
/// There is no separate anonymous endpoint, and there should not be: an
/// anonymous consultation is an ordinary one whose patient is named by an alias.
/// `POST /consultations/instant` already takes `isAnonymous` and `alias`, so
/// this is now just the answers from the form on their way to that call, and
/// the consultation the API mints is the session.
///
/// The alias is the only name the doctor ever sees, which is why it is carried
/// as a value object rather than as a loose string.
class AnonymousSession {
  const AnonymousSession({
    required this.codeName,
    required this.mode,
    required this.language,
    this.kind = ConsultOptionKind.instant,
    this.concern,
  });

  /// From a completed booking form.
  factory AnonymousSession.from(AnonymousBooking booking) {
    return AnonymousSession(
      codeName: booking.codeName,
      mode: booking.mode,
      language: booking.language,
      kind: booking.kind,
      concern: booking.concern,
    );
  }

  final CodeName codeName;

  /// Always [ConsultationMode.audio] — see `AnonymousBooking.mode`.
  final ConsultationMode mode;

  final ConsultLanguage language;

  /// Whether the patient wants a doctor now or a slot booked for later. Both
  /// run under the alias; only the route through the app differs.
  final ConsultOptionKind kind;

  /// What the patient wrote about why they are consulting.
  ///
  /// It travels onto the consultation itself, so the doctor reads it before
  /// deciding whether to answer. On an anonymous call it is the **only** thing
  /// they know about the person ringing them — before this was carried, a
  /// doctor was asked to accept a call from an alias with nothing else on the
  /// sheet at all.
  final String? concern;

  bool get isScheduled => kind == ConsultOptionKind.scheduled;

  /// The alias as the doctor sees it, and as it is sent to the API.
  String get displayName => codeName.normalised;
}
