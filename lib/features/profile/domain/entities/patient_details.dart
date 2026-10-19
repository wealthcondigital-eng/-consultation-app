import 'blood_group.dart';
import 'gender.dart';
import 'patient_account.dart';

/// The part of a patient's record they may change themselves.
///
/// Deliberately excludes the phone number: that is the verified identity the
/// whole account is keyed on, and changing it needs a fresh OTP rather than a
/// text field. It also excludes the uid and the consent stamps, which are
/// records of something that happened and must not be rewritten.
class PatientDetails {
  const PatientDetails({
    required this.fullName,
    this.email,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
  });

  /// Seeds the form from the stored account.
  factory PatientDetails.from(PatientAccount account) => PatientDetails(
    fullName: account.fullName,
    email: account.email,
    dateOfBirth: account.dateOfBirth,
    gender: account.gender,
    bloodGroup: account.bloodGroup,
  );

  static const int minNameLength = 2;

  /// Matches the age ceiling the onboarding form enforces.
  static const int maxAgeYears = 120;

  final String fullName;
  final String? email;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final BloodGroup? bloodGroup;

  bool get hasValidName => fullName.trim().length >= minNameLength;

  /// Optional, but must look like an address when given. Intentionally loose —
  /// the only authority on whether an address works is sending to it.
  bool get hasValidEmail {
    final value = email?.trim() ?? '';
    if (value.isEmpty) return true;

    return RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(value);
  }

  /// Optional, but a date in the future or beyond a plausible lifespan is a
  /// typo rather than a fact.
  bool isValidDateOfBirth(DateTime now) {
    final date = dateOfBirth;
    if (date == null) return true;

    if (date.isAfter(now)) return false;
    return !date.isBefore(DateTime(now.year - maxAgeYears, now.month, now.day));
  }

  bool isComplete(DateTime now) =>
      hasValidName && hasValidEmail && isValidDateOfBirth(now);

  PatientDetails copyWith({
    String? fullName,
    String? email,
    DateTime? dateOfBirth,
    Gender? gender,
    BloodGroup? bloodGroup,
    bool clearDateOfBirth = false,
  }) {
    return PatientDetails(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      dateOfBirth: clearDateOfBirth ? null : dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
    );
  }
}
