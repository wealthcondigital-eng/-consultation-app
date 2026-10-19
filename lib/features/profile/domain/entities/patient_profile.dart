import 'gender.dart';

/// The details a patient must supply before their first consultation.
class PatientProfile {
  const PatientProfile({
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.dataProcessingConsent,
    required this.termsAccepted,
  });

  /// Bounds live here so the validator and the UI's error copy cannot drift.
  static const int minNameLength = 2;

  /// The account holder must be an adult, for two independent Indian rules:
  /// the DPDP Act 2023 treats anyone under 18 as a child and requires
  /// verifiable parental consent before their data may be processed, and the
  /// NMC Telemedicine Practice Guidelines 2020 only permit a consultation with
  /// a minor when an identified adult is present.
  ///
  /// A minor is not turned away from care — the guardian holds the account and
  /// the child is seen under it. That flow does not exist yet; until it does,
  /// this is the line.
  static const int minAgeYears = 18;

  /// Beyond a plausible lifespan is a typo, not a fact.
  static const int maxAgeYears = 120;

  final String fullName;
  final DateTime? dateOfBirth;
  final Gender? gender;

  /// Consent to processing personal data for healthcare consultations.
  /// Required by the DPDP Act 2023 — a profile cannot be saved without it.
  final bool dataProcessingConsent;

  /// Acceptance of the terms and conditions.
  final bool termsAccepted;

  bool get hasValidName => fullName.trim().length >= minNameLength;

  /// Whole years on [now], or null without a date of birth.
  ///
  /// Matches `PatientAccount.ageAt` — the birthday has to have passed this
  /// year, or someone born in December is briefly a year older than they are.
  int? ageAt(DateTime now) {
    final date = dateOfBirth;
    if (date == null) return null;

    final hasHadBirthday =
        now.month > date.month ||
        (now.month == date.month && now.day >= date.day);
    return now.year - date.year - (hasHadBirthday ? 0 : 1);
  }

  /// A date that is present, in the past, and inside a plausible lifespan.
  ///
  /// Deliberately separate from [isOldEnough]: a date in the future is a
  /// mistake to correct, being 16 is not, and the two want different words on
  /// screen.
  bool isDateOfBirthPlausible(DateTime now) {
    final age = ageAt(now);
    return age != null && age >= 0 && age <= maxAgeYears;
  }

  bool isOldEnough(DateTime now) {
    final age = ageAt(now);
    return age != null && age >= minAgeYears;
  }

  bool isComplete(DateTime now) =>
      hasValidName &&
      isDateOfBirthPlausible(now) &&
      isOldEnough(now) &&
      gender != null &&
      dataProcessingConsent &&
      termsAccepted;
}
