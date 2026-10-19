import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';

/// One review a patient left after consulting this doctor.
///
/// Written on the feedback screen the call hands over to, and shown on the
/// doctor's profile. Before the rating was stored, a doctor's star average came
/// from nowhere a patient could read — a number with no sentences behind it.
///
/// **The reviewer is not named.** The API sends `Verified patient` for every
/// one of them, and that is deliberate rather than a gap to fill in later: a
/// patient's name is not something the directory hands out, and an anonymous
/// consultation's alias is not either — attaching an alias to a doctor and a
/// date is the one thing anonymity here promises not to do. The label is also
/// the true one: only a completed consultation can be rated.
class DoctorReview {
  const DoctorReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.authorName = 'Verified patient',
    this.mode,
  });

  final String id;

  /// Out of five.
  final int rating;

  /// What they wrote. Never empty — a rating with no words is counted in the
  /// average and not listed here, because a wall of empty five-star rows pushes
  /// the one review with something to say off the screen.
  final String comment;

  final String authorName;

  /// How the consultation was held, when the API says. Null when it does not.
  final ConsultationMode? mode;

  final DateTime createdAt;

  /// `Sep 11, 2026`
  /// The author as shown — the stand-in name is translated, a real one is not.
  String get authorLabel => tr(authorName);

  String get dateLabel => AppDateFormat.monthDayYear(createdAt);
}
