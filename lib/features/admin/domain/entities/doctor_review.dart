/// A submitted registration as the reviewer sees it.
///
/// Deliberately excludes payout details: approving credentials is no reason to
/// see where someone's money goes, and the RLS policies enforce the same thing.
class DoctorReview {
  const DoctorReview({
    required this.doctorId,
    required this.fullName,
    required this.submittedAt,
    this.medicalDegree,
    this.registrationNumber,
    this.specialty,
    this.state,
    this.city,
    this.yearsOfExperience,
    this.certificatePath,
    this.certificateName,
    this.phone,
  });

  final String doctorId;
  final String fullName;
  final DateTime? submittedAt;

  final String? medicalDegree;
  final String? registrationNumber;
  final String? specialty;
  final String? state;
  final String? city;
  final int? yearsOfExperience;

  /// Object path in the certificates bucket, or null when the doctor filled
  /// the form by hand — which is allowed, and worth showing the reviewer.
  final String? certificatePath;
  final String? certificateName;

  final String? phone;

  bool get hasCertificate => (certificatePath ?? '').isNotEmpty;

  /// `Mumbai, Maharashtra` — whichever parts are known.
  String get locationLabel {
    final parts = [city, state].where((part) => (part ?? '').isNotEmpty);
    return parts.isEmpty ? 'Location not given' : parts.join(', ');
  }

  /// `MBBS · Cardiology · 12 yrs`
  String get credentialsLabel {
    final parts = [
      if ((medicalDegree ?? '').isNotEmpty) medicalDegree!,
      if ((specialty ?? '').isNotEmpty) specialty!,
      if (yearsOfExperience != null) '$yearsOfExperience yrs',
    ];
    return parts.isEmpty ? 'No credentials given' : parts.join(' · ');
  }
}
