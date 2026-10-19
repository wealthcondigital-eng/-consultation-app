import '../../../../core/format/app_date_format.dart';
import 'blood_group.dart';
import 'gender.dart';
import 'medical_history.dart';

/// The patient's account as shown on My Profile.
///
/// Distinct from `PatientProfile`, which is the onboarding form and its
/// validation rules. This is the stored record read back afterwards.
class PatientAccount {
  const PatientAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.avatarUrl,
    this.medicalHistory,
  });

  final String id;
  final String fullName;
  final String email;

  /// Already formatted for display, e.g. `+1 (555) 234-5678` — the backend
  /// stores E.164 and formats per the patient's country.
  final String phoneNumber;

  final DateTime? dateOfBirth;
  final Gender? gender;
  final BloodGroup? bloodGroup;

  /// Where the profile photo is served from, or null when there is none.
  ///
  /// A **path on the API** — `/patients/me/photo` — not a public URL. The
  /// route is behind the same bearer token as the record, so the bytes are
  /// fetched by `RemoteAvatar`, which attaches it; a bare `Image.network`
  /// sends no headers and would get a 401.
  final String? avatarUrl;

  final MedicalHistory? medicalHistory;

  /// `Alexander` — what a greeting calls the patient.
  ///
  /// Null when the stored name is blank, so the caller can fall back to a
  /// generic greeting rather than addressing an empty string.
  String? get firstName {
    final first = fullName.trim().split(RegExp(r'\s+')).firstOrNull;
    return (first == null || first.isEmpty) ? null : first;
  }

  /// `AW` — the avatar's fallback when there is no photo.
  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';

    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  /// `May 18, 1991`, or a dash when the patient has not given one.
  String get dateOfBirthLabel => switch (dateOfBirth) {
    final date? => AppDateFormat.monthDayYear(date),
    null => '—',
  };

  /// The account with one field changed.
  ///
  /// Only for the two the profile screen writes without re-reading: the photo,
  /// where the server has already answered with the stored path, and the
  /// medical record, which its own screen hands back. Everything else goes
  /// through the edit form and a fresh read — the backend is the authority on
  /// what was actually stored.
  PatientAccount copyWith({
    String? avatarUrl,
    MedicalHistory? medicalHistory,
    bool clearAvatar = false,
  }) {
    return PatientAccount(
      id: id,
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodGroup: bloodGroup,
      avatarUrl: clearAvatar ? null : avatarUrl ?? this.avatarUrl,
      medicalHistory: medicalHistory ?? this.medicalHistory,
    );
  }

  /// Whole years, or null without a date of birth.
  int? ageAt(DateTime now) {
    final date = dateOfBirth;
    if (date == null) return null;

    final hasHadBirthday =
        now.month > date.month ||
        (now.month == date.month && now.day >= date.day);
    return now.year - date.year - (hasHadBirthday ? 0 : 1);
  }
}
