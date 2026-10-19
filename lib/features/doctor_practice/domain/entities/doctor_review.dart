import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';

/// One review, as the doctor who was reviewed reads it.
///
/// **Named, unlike the directory's copy of the same rows.** A patient browsing
/// doctors is shown `Verified patient`, because who else consulted somebody is
/// not the directory's to hand out. The doctor was there — they already know
/// who they saw, and a page of identical `Verified patient` headings tells them
/// nothing about which consultation went wrong.
///
/// The exception is an anonymous consultation, which stays anonymous here too.
/// That agreement was made with the platform rather than with the directory,
/// and naming the patient to the doctor afterwards would be exactly the
/// disclosure the feature exists to prevent — so [authorName] reads
/// `Anonymous user` and [photoUrl] is null, whatever the account holds.
class DoctorReview {
  const DoctorReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.authorName,
    required this.mode,
    required this.createdAt,
    this.isAnonymous = false,
    this.photoUrl,
  });

  final String id;

  /// Out of five.
  final int rating;

  /// What they wrote. Never empty — a rating with no words is already in the
  /// average, and the API leaves those out.
  final String comment;

  /// The patient's name, or `Anonymous user`.
  final String authorName;

  /// The API path their photo is served from, or null when there is none — and
  /// always null on an anonymous review.
  final String? photoUrl;

  final ConsultationMode mode;

  /// When the consultation ended.
  final DateTime createdAt;

  final bool isAnonymous;

  /// One or two letters for the avatar, or a lock glyph's stand-in when the
  /// review is anonymous and there is no name to take them from.
  String get initials {
    if (isAnonymous) return '?';

    final parts = authorName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  /// `Sep 11, 2026`
  String get whenLabel => AppDateFormat.monthDayYear(createdAt);

  /// `Video · Sep 11, 2026`
  String get detailLabel => '${tr(mode.shortLabel)} · $whenLabel';
}
