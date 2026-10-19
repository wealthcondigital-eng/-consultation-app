import '../../domain/entities/patient_profile.dart';

/// Maps the domain entity to the wire format.
///
/// Kept out of the entity so a backend field rename never reaches the domain.
extension PatientProfilePayload on PatientProfile {
  /// [now] is injectable so the consent stamps are deterministic in tests.
  Map<String, Object?> toPayload({DateTime? now}) {
    final at = now ?? DateTime.now();
    final stamp = at.toUtc().toIso8601String();
    final date = dateOfBirth;

    return {
      'full_name': fullName.trim(),
      // The API's onboarding contract is an age in whole years, stamped with
      // when it was given — and it rejects the profile without one ("must be
      // an integer number"). Derived from the date of birth, so the form asks
      // once and both agree.
      'reported_age': date == null ? null : ageOn(date, at),
      'reported_age_at': stamp,
      // A date of birth rather than a reported age: it does not go stale, and
      // it is the only form in which the 18+ check can be re-verified later.
      // The column is `date`, not `timestamptz` — send the calendar day only,
      // matching `PatientDetailsPayload`.
      'date_of_birth': date == null
          ? null
          : '${date.year.toString().padLeft(4, '0')}-'
                '${date.month.toString().padLeft(2, '0')}-'
                '${date.day.toString().padLeft(2, '0')}',
      'gender': gender?.key,
      // Timestamps rather than booleans: the DPDP Act 2023 expects a record of
      // *when* consent was given, not merely that it was. `SavePatientProfile`
      // rejects an incomplete profile, so both are always present here.
      'data_processing_consent_at': dataProcessingConsent ? stamp : null,
      'terms_accepted_at': termsAccepted ? stamp : null,
    };
  }
}

/// Whole years from [birth] to [on] — not yet a year older until the
/// birthday itself has come round.
int ageOn(DateTime birth, DateTime on) {
  var years = on.year - birth.year;
  if (on.month < birth.month ||
      (on.month == birth.month && on.day < birth.day)) {
    years -= 1;
  }
  return years < 0 ? 0 : years;
}
