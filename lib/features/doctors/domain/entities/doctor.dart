import '../../../../core/l10n/tr.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import 'doctor_review.dart';

/// A doctor as shown in a listing or a card.
class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.speciality,
    required this.yearsOfExperience,
    required this.rating,
    required this.consultationFee,
    this.audioConsultationFee,
    this.currencySymbol = '₹',
    this.isVerified = false,
    this.isAvailableNow = false,
    this.supportedModes = const {
      ConsultationMode.video,
      ConsultationMode.audio,
    },
    this.about,
    this.qualifications = const [],
    this.languages = const [],
    this.consultationsDone = 0,
    this.reviewCount = 0,
    this.photoUrl,
    this.clinicName,
    this.city,
    this.reviews = const [],
    this.registrationNumber,
  });

  /// The doctor's NMC or State Medical Council registration number.
  ///
  /// Not decoration. The NMC Telemedicine Practice Guidelines 2020 require a
  /// registered practitioner to display this in **every** communication with a
  /// patient — the profile they choose from, the prescription, the fee
  /// receipt. It was collected at onboarding and shown only to the internal
  /// reviewer, which is the one place it is not required.
  ///
  /// Nullable because the listing endpoint returns the short form of a doctor;
  /// a card renders what it has and the profile fills the rest in.
  final String? registrationNumber;

  // --- The profile ---------------------------------------------------------
  //
  // Everything below this line is what a patient reads *before* deciding, and
  // none of it existed. Tapping a doctor rang them immediately: the name, the
  // fee and a star were the whole basis for choosing who to discuss your health
  // with, and there was no way to look at somebody without calling them.
  //
  // All of it is optional. The listing endpoint returns the short form and the
  // profile endpoint the long one, so a card built from a list row renders what
  // it has and the detail screen fills in the rest once it loads.

  /// The doctor's own description of their practice.
  final String? about;

  /// `MBBS`, `MD (Cardiology)` — in the order the doctor lists them.
  final List<String> qualifications;

  /// Which languages they consult in. The single most common reason a patient
  /// asks for a different doctor, and it was nowhere in the app.
  final List<String> languages;

  /// Completed consultations, all time. A count a patient can weigh, unlike a
  /// star average over an unknown number of ratings.
  final int consultationsDone;

  /// How many ratings [rating] is an average of. Four-point-nine out of three
  /// reviews and out of three hundred are different claims.
  final int reviewCount;

  /// The most recent reviews that carry a comment, newest first.
  ///
  /// Empty on a listing row — they come with the profile read — and empty on a
  /// doctor nobody has written about yet, which the screen shows as an
  /// invitation rather than as a gap. Fewer than [reviewCount], because a
  /// rating with no words is counted in the average and not listed.
  final List<DoctorReview> reviews;

  /// A path on the API — see `RemoteAvatar`. Null when they have not added one.
  final String? photoUrl;

  final String? clinicName;
  final String? city;

  final String id;

  /// Including the title, e.g. `Dr. Sunita Rao`.
  final String name;

  /// Display name of their speciality, e.g. `Senior Cardiologist`.
  final String speciality;

  final int yearsOfExperience;

  /// Out of five, to one decimal place.
  final double rating;

  /// The standard fee, charged for a video consultation. Whole currency units
  /// — rupees, not paise.
  final int consultationFee;

  /// What an audio consultation costs, when the doctor prices it differently.
  /// Null means they charge the same as for video.
  final int? audioConsultationFee;

  final String currencySymbol;

  final bool isVerified;

  /// True when the doctor can take a consultation right now.
  final bool isAvailableNow;

  /// Which call types this doctor takes. Most take both; some are voice-only,
  /// which matters as soon as the patient has already chosen a mode.
  final Set<ConsultationMode> supportedModes;

  bool supports(ConsultationMode mode) => supportedModes.contains(mode);

  /// `Senior Cardiologist • 15 yrs exp`
  String get credentials => tr('{speciality} • {years} yrs exp', {
    'speciality': tr(speciality),
    'years': yearsOfExperience,
  });

  /// `15 yrs Exp`
  String get experienceLabel =>
      tr('{years} yrs Exp', {'years': yearsOfExperience});

  /// `4.9`
  String get formattedRating => rating.toStringAsFixed(1);

  /// What this doctor charges for [mode].
  int feeFor(ConsultationMode mode) => switch (mode) {
    ConsultationMode.video => consultationFee,
    ConsultationMode.audio => audioConsultationFee ?? consultationFee,
  };

  /// `₹800` — the standard fee, as shown in a listing.
  String get formattedFee => formatFee(consultationFee);

  String formatFee(int amount) => '$currencySymbol$amount';

  /// `₹600` — what a voice call costs, which is often less than a video one.
  String get formattedAudioFee => formatFee(feeFor(ConsultationMode.audio));

  /// `MBBS · MD (Cardiology)`, or null when none are on file.
  String? get qualificationsLabel =>
      qualifications.isEmpty ? null : qualifications.join(' · ');

  /// `English, Hindi, Marathi`, or null when none are on file.
  String? get languagesLabel => languages.isEmpty ? null : languages.join(', ');

  /// `4.9 (312)` — the average with the number of ratings behind it.
  String get ratingLabel =>
      reviewCount == 0 ? formattedRating : '$formattedRating ($reviewCount)';

  /// `4.9 out of 312 reviews` — the sentence under a reviews heading.
  String get reviewSummary => switch (reviewCount) {
    0 => tr('No ratings yet'),
    1 => tr('{rating} from 1 rating', {'rating': formattedRating}),
    _ => tr('{rating} from {count} ratings', {
      'rating': formattedRating,
      'count': reviewCount,
    }),
  };

  /// True when there is enough on file for the About section to be worth
  /// drawing. A heading over an empty card is worse than no heading.
  bool get hasProfileDetail =>
      (about ?? '').trim().isNotEmpty ||
      qualifications.isNotEmpty ||
      languages.isNotEmpty;

  /// Folds a freshly loaded profile onto the row a list already had.
  ///
  /// The detail screen opens from a listing row it was handed, so the name and
  /// the fee are on screen immediately and the long form fills in behind them.
  /// A null field on [other] leaves this one's value alone, so a profile
  /// response that omits something does not blank what was already shown.
  Doctor mergedWith(Doctor other) {
    return Doctor(
      id: other.id,
      name: other.name.isEmpty ? name : other.name,
      speciality: other.speciality.isEmpty ? speciality : other.speciality,
      yearsOfExperience: other.yearsOfExperience == 0
          ? yearsOfExperience
          : other.yearsOfExperience,
      rating: other.rating == 0 ? rating : other.rating,
      consultationFee: other.consultationFee == 0
          ? consultationFee
          : other.consultationFee,
      audioConsultationFee: other.audioConsultationFee ?? audioConsultationFee,
      currencySymbol: other.currencySymbol,
      isVerified: other.isVerified || isVerified,
      isAvailableNow: other.isAvailableNow,
      supportedModes: other.supportedModes,
      about: other.about ?? about,
      qualifications: other.qualifications.isEmpty
          ? qualifications
          : other.qualifications,
      languages: other.languages.isEmpty ? languages : other.languages,
      consultationsDone: other.consultationsDone == 0
          ? consultationsDone
          : other.consultationsDone,
      reviewCount: other.reviewCount == 0 ? reviewCount : other.reviewCount,
      photoUrl: other.photoUrl ?? photoUrl,
      clinicName: other.clinicName ?? clinicName,
      city: other.city ?? city,
      reviews: other.reviews.isEmpty ? reviews : other.reviews,
    );
  }

  /// Whether this doctor matches a free-text search.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;

    return name.toLowerCase().contains(needle) ||
        speciality.toLowerCase().contains(needle);
  }
}
