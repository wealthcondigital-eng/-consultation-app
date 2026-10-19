import '../../../../core/l10n/tr.dart';
import '../../../doctor_onboarding/domain/entities/doctor_availability.dart';

/// The doctor's own record, as they see it.
///
/// Wider than the `Doctor` a **patient** is shown: the registration number and
/// the review status are on here and on nothing a patient can call. That split
/// is the API's — `GET /doctors/me/profile` and `GET /doctors/:id` return
/// different shapes on purpose, so no future edit can leak a payout detail by
/// forgetting to strip it.
class DoctorPracticeProfile {
  const DoctorPracticeProfile({
    required this.id,
    required this.fullName,
    required this.displayName,
    required this.status,
    this.phone,
    this.email,
    this.medicalDegree,
    this.registrationNumber,
    this.specialty,
    this.state,
    this.city,
    this.yearsOfExperience,
    this.bio,
    this.languages = const [],
    this.photoUrl,
    this.rejectionReason,
    this.submittedAt,
    this.videoFee,
    this.audioFee,
    this.availability = const DoctorAvailability(),
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.hasCertificate = false,
  });

  final String id;

  /// As the doctor typed it, with no title added. What the edit form seeds
  /// from — prefixing it would put `Dr.` in the field and then twice over on
  /// the next save.
  final String fullName;

  /// With the title, e.g. `Dr. Amit Verma`. What a header renders.
  final String displayName;

  /// The review status: `draft`, `under_review`, `changes_requested`,
  /// `approved` or `rejected`.
  final String status;

  final String? phone;
  final String? email;
  final String? medicalDegree;

  /// The council number the review was made against.
  final String? registrationNumber;

  final String? specialty;
  final String? state;
  final String? city;
  final int? yearsOfExperience;

  final String? bio;
  final List<String> languages;

  /// A path on the API — see `RemoteAvatar`.
  final String? photoUrl;

  /// Why a registration was turned down, or what needs changing. Null unless
  /// the status is one of those two.
  final String? rejectionReason;

  final DateTime? submittedAt;

  final int? videoFee;
  final int? audioFee;

  final DoctorAvailability availability;

  final double ratingAverage;
  final int ratingCount;

  /// Whether a degree certificate is on file. The document itself is not
  /// linked: a doctor re-reading their own paperwork is not a flow the app has,
  /// and a URL that exists is a URL that leaks.
  final bool hasCertificate;

  bool get isApproved => status == 'approved';

  /// True while the platform is still deciding.
  bool get isUnderReview => status == 'under_review';

  /// True when the reviewer asked for something. [rejectionReason] then says
  /// what, and it is the only thing that tells the doctor how to proceed.
  bool get needsAttention =>
      status == 'rejected' || status == 'changes_requested';

  /// `Approved` / `Under review` / `Changes requested`
  String get statusLabel => switch (status) {
    'approved' => 'Approved',
    'under_review' => 'Under review',
    'changes_requested' => 'Changes requested',
    'rejected' => 'Not approved',
    _ => 'Incomplete',
  };

  /// `4.8 ★ (36)`, or a plain note before the first rating — an unrated doctor
  /// is not a badly rated one, and `0.0 ★` says the opposite.
  String get ratingLabel => ratingCount == 0
      ? tr('Not rated yet')
      : '${ratingAverage.toStringAsFixed(1)} ★ ($ratingCount)';

  /// `Mumbai, Maharashtra`, or whichever half is known.
  String get locationLabel => [
    city,
    state,
  ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

  /// `English, Hindi, Marathi`
  String get languagesLabel => languages.isEmpty ? '—' : languages.join(', ');

  /// `₹500`, or a dash before the doctor has chosen.
  String get videoFeeLabel => videoFee == null ? '—' : '₹$videoFee';

  String get audioFeeLabel => audioFee == null ? '—' : '₹$audioFee';

  /// `AV` — for the avatar's fallback. The title is dropped, since every
  /// doctor has one and a circle full of `D`s tells you nothing.
  String get initials {
    final words = fullName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .where(
          (word) => !const {
            'dr',
            'dr.',
            'prof',
            'prof.',
          }.contains(word.toLowerCase()),
        )
        .toList();

    if (words.isEmpty) return 'Dr';

    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }

  DoctorPracticeProfile copyWith({
    String? photoUrl,
    bool clearPhoto = false,
    DoctorAvailability? availability,
    int? videoFee,
    int? audioFee,
  }) {
    return DoctorPracticeProfile(
      id: id,
      fullName: fullName,
      displayName: displayName,
      status: status,
      phone: phone,
      email: email,
      medicalDegree: medicalDegree,
      registrationNumber: registrationNumber,
      specialty: specialty,
      state: state,
      city: city,
      yearsOfExperience: yearsOfExperience,
      bio: bio,
      languages: languages,
      photoUrl: clearPhoto ? null : photoUrl ?? this.photoUrl,
      rejectionReason: rejectionReason,
      submittedAt: submittedAt,
      videoFee: videoFee ?? this.videoFee,
      audioFee: audioFee ?? this.audioFee,
      availability: availability ?? this.availability,
      ratingAverage: ratingAverage,
      ratingCount: ratingCount,
      hasCertificate: hasCertificate,
    );
  }
}

/// The fields a doctor may change themselves, as the edit form holds them.
///
/// What is **not** here is the point. The registration number, the degree and
/// the specialty were read off a certificate a reviewer accepted, and letting
/// an approved doctor rewrite them afterwards would make the approval
/// meaningless — the platform approved a named person holding a named
/// qualification, not a row that can later say something else. Those three
/// change by re-filing, which puts the record back through review.
class DoctorProfileEdits {
  const DoctorProfileEdits({
    this.fullName = '',
    this.email = '',
    this.state = '',
    this.city = '',
    this.yearsOfExperience,
    this.bio = '',
    this.languages = const [],
  });

  /// Seeds the form from the stored profile.
  factory DoctorProfileEdits.from(DoctorPracticeProfile profile) {
    return DoctorProfileEdits(
      fullName: profile.fullName,
      email: profile.email ?? '',
      state: profile.state ?? '',
      city: profile.city ?? '',
      yearsOfExperience: profile.yearsOfExperience,
      bio: profile.bio ?? '',
      languages: profile.languages,
    );
  }

  static const int minNameLength = 3;
  static const int maxBioLength = 600;
  static const int maxYears = 70;

  final String fullName;
  final String email;
  final String state;
  final String city;
  final int? yearsOfExperience;
  final String bio;
  final List<String> languages;

  String? get nameError => fullName.trim().length < minNameLength
      ? 'Please enter your full name.'
      : null;

  /// Optional, but must look like an address when given. Intentionally loose —
  /// the only authority on whether an address works is sending to it.
  String? get emailError {
    final value = email.trim();
    if (value.isEmpty) return null;

    return RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(value)
        ? null
        : 'Please enter a valid email address.';
  }

  String? get yearsError {
    final years = yearsOfExperience;
    if (years == null) return null;
    if (years < 0) return 'Years of experience cannot be negative.';
    if (years > maxYears) return 'Please check your years of experience.';
    return null;
  }

  String? get bioError => bio.length > maxBioLength
      ? tr('Please keep your bio under {max} characters.', {
          'max': maxBioLength,
        })
      : null;

  bool get isValid =>
      nameError == null &&
      emailError == null &&
      yearsError == null &&
      bioError == null;

  DoctorProfileEdits copyWith({
    String? fullName,
    String? email,
    String? state,
    String? city,
    int? yearsOfExperience,
    String? bio,
    List<String>? languages,
    bool clearYears = false,
  }) {
    return DoctorProfileEdits(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      state: state ?? this.state,
      city: city ?? this.city,
      yearsOfExperience: clearYears
          ? null
          : yearsOfExperience ?? this.yearsOfExperience,
      bio: bio ?? this.bio,
      languages: languages ?? this.languages,
    );
  }

  /// The body `PATCH /doctors/me/profile` expects.
  ///
  /// Every key is sent, with an empty string becoming null so that clearing a
  /// field actually clears it. The API treats a *missing* key as "leave it
  /// alone", which is the right default for a partial screen — this form owns
  /// all seven, so it says so.
  Map<String, Object?> toPayload() => {
    'fullName': fullName.trim(),
    'email': email.trim().isEmpty ? null : email.trim().toLowerCase(),
    'state': state.trim().isEmpty ? null : state.trim(),
    'city': city.trim().isEmpty ? null : city.trim(),
    'yearsOfExperience': yearsOfExperience,
    'bio': bio.trim().isEmpty ? null : bio.trim(),
    'languages': languages,
  };
}
