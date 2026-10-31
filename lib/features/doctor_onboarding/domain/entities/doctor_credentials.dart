/// The individually fillable parts of a doctor's credentials.
///
/// Named so the UI can mark exactly which fields came back from the
/// certificate rather than flagging the whole form as verified.
enum DoctorCredentialField {
  fullName,
  medicalDegree,
  registrationNumber,
  specialty,
  state,
  city,
  yearsOfExperience,
  languages,
}

/// What a doctor practises as — parsed from their certificate where possible,
/// and editable either way.
class DoctorCredentials {
  const DoctorCredentials({
    this.fullName = '',
    this.medicalDegree,
    this.registrationNumber = '',
    this.specialty,
    this.state,
    this.city,
    this.yearsOfExperience,
    this.languages = const [],
    this.verifiedFields = const {},
  });

  static const int minNameLength = 3;
  static const int minRegistrationLength = 4;

  final String fullName;

  /// e.g. `MD - General Medicine`. Chosen from the options the backend lists.
  final String? medicalDegree;

  /// Council registration, e.g. `REG-9920-A`.
  final String registrationNumber;

  final String? specialty;
  final String? state;
  final String? city;
  final int? yearsOfExperience;

  /// What the doctor can hold a consultation in. At least one, because a
  /// patient choosing a doctor reads this before anything else.
  final List<String> languages;

  /// Which fields were read off the certificate and checked against the
  /// register — these get a tick in the form.
  final Set<DoctorCredentialField> verifiedFields;

  bool isVerified(DoctorCredentialField field) =>
      verifiedFields.contains(field);

  /// True when anything at all came back from the certificate.
  bool get isAutoFilled => verifiedFields.isNotEmpty;

  String? get fullNameError {
    final name = fullName.trim();
    if (name.isEmpty) return 'Enter the name on your certificate.';
    if (name.length < minNameLength) return 'That name looks too short.';
    return null;
  }

  String? get registrationNumberError {
    final number = registrationNumber.trim();
    if (number.isEmpty) return 'Enter your registration number.';
    if (number.length < minRegistrationLength) {
      return 'That registration number looks too short.';
    }
    if (!RegExp(r'^[A-Za-z0-9\-/]+$').hasMatch(number)) {
      return 'Letters, numbers and hyphens only.';
    }
    return null;
  }

  /// Every field the doctor still has to supply, in form order — empty when
  /// the step can be submitted.
  List<DoctorCredentialField> get missingFields => [
    if (fullNameError != null) DoctorCredentialField.fullName,
    if (medicalDegree == null) DoctorCredentialField.medicalDegree,
    if (registrationNumberError != null)
      DoctorCredentialField.registrationNumber,
    if (specialty == null) DoctorCredentialField.specialty,
    if (state == null) DoctorCredentialField.state,
    if (city == null) DoctorCredentialField.city,
    if (yearsOfExperience == null) DoctorCredentialField.yearsOfExperience,
    if (languages.isEmpty) DoctorCredentialField.languages,
  ];

  bool get isComplete => missingFields.isEmpty;

  /// `8 Years`, or null when it has not been set.
  String? get experienceLabel => switch (yearsOfExperience) {
    final years? => '$years ${years == 1 ? 'Year' : 'Years'}',
    null => null,
  };

  DoctorCredentials copyWith({
    String? fullName,
    String? medicalDegree,
    String? registrationNumber,
    String? specialty,
    String? state,
    String? city,
    int? yearsOfExperience,
    List<String>? languages,
    Set<DoctorCredentialField>? verifiedFields,
    // Changing state normally clears the city, which is the one field that
    // depends on another.
    bool clearCity = false,
  }) {
    return DoctorCredentials(
      fullName: fullName ?? this.fullName,
      medicalDegree: medicalDegree ?? this.medicalDegree,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      specialty: specialty ?? this.specialty,
      state: state ?? this.state,
      city: clearCity ? null : city ?? this.city,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      languages: languages ?? this.languages,
      verifiedFields: verifiedFields ?? this.verifiedFields,
    );
  }
}
