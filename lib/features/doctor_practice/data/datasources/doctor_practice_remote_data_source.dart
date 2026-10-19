import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctor_onboarding/domain/entities/bank_account.dart';
import '../../../doctor_onboarding/domain/entities/doctor_availability.dart';
import '../../domain/entities/doctor_credential.dart';
import '../../domain/entities/doctor_earnings.dart';
import '../../domain/entities/doctor_patient.dart';
import '../../domain/entities/doctor_patient_detail.dart';
import '../../domain/entities/doctor_review.dart';
import '../../domain/entities/doctor_practice_profile.dart';
import '../../domain/entities/doctor_settings.dart';

/// Supplies everything a doctor manages about their practice.
abstract interface class DoctorPracticeRemoteDataSource {
  Future<DoctorPracticeProfile> fetchProfile();

  /// Answers with the stored profile, so the screen renders what was actually
  /// written rather than what it hoped it sent.
  Future<DoctorPracticeProfile> updateProfile(Map<String, Object?> payload);

  Future<String?> uploadPhoto(String filePath);

  Future<String?> removePhoto();

  Future<List<DoctorPatient>> fetchPatients({String? search, int limit});

  /// One patient and what this doctor has seen them for.
  ///
  /// Anonymous consultations have no patient to fetch — the id is withheld
  /// precisely so an alias cannot be joined to an account — so this is only
  /// ever called for a named one.
  Future<DoctorPatientDetail> fetchPatientDetail(String patientId);

  /// What patients wrote, named. See [DoctorReview] for why the doctor's copy
  /// names people and the directory's does not.
  Future<List<DoctorReview>> fetchReviews({int limit});

  Future<DoctorEarnings> fetchEarnings(EarningsPeriod period);

  Future<BankAccountSummary> fetchBankAccount();

  Future<BankAccountSummary> saveBankAccount(BankAccount account);

  Future<List<DoctorCredential>> fetchCredentials();

  /// Adds a certificate to the doctor's own profile.
  ///
  /// [title] is the claim — `Fellowship in Interventional Cardiology` — and is
  /// what patients read once a reviewer accepts it. The file backs it up and
  /// never leaves the private bucket.
  ///
  /// Answers with the stored document, awaiting review.
  Future<DoctorCredential> addCertificate({
    required String title,
    required String filePath,
    required String contentType,
  });

  Future<void> removeCertificate(String id);

  Future<DoctorSettings> fetchSettings();

  Future<DoctorSettings> updateSettings(Map<String, Object?> payload);
}

/// The doctor's practice, on the consultation API.
///
/// | Method | Path                       |
/// | ------ | -------------------------- |
/// | GET    | /doctors/me/profile        |
/// | PATCH  | /doctors/me/profile        |
/// | POST   | /doctors/me/photo          | multipart, field `photo`
/// | DELETE | /doctors/me/photo          |
/// | GET    | /doctors/me/patients       | ?search= &limit=
/// | GET    | /doctors/me/earnings       | ?period=
/// | GET    | /doctors/me/bank-account   | masked
/// | PUT    | /doctors/me/bank-account   |
/// | GET    | /doctors/me/documents      |
/// | POST   | /doctors/me/certificates   | multipart: `certificate` + `title`
/// | DELETE | /doctors/me/certificates/:id |
/// | GET    | /doctors/me/settings       |
/// | PATCH  | /doctors/me/settings       |
class ApiDoctorPracticeRemoteDataSource
    implements DoctorPracticeRemoteDataSource {
  const ApiDoctorPracticeRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  Future<DoctorPracticeProfile> fetchProfile() async {
    final body = await _client.get('/doctors/me/profile');
    return _profileFrom(body['profile']);
  }

  @override
  Future<DoctorPracticeProfile> updateProfile(
    Map<String, Object?> payload,
  ) async {
    // PATCH: the registration number, the degree and the specialty are absent
    // from the payload rather than sent and ignored. They were reviewed, and a
    // correction to one of them re-files the application.
    final body = await _client.patch('/doctors/me/profile', body: payload);
    return _profileFrom(body['profile']);
  }

  @override
  Future<String?> uploadPhoto(String filePath) async {
    final body = await _client.uploadFile(
      '/doctors/me/photo',
      field: 'photo',
      filePath: filePath,
      contentType: _contentTypeOf(filePath),
    );

    return body['photoUrl'] as String?;
  }

  @override
  Future<String?> removePhoto() async {
    final body = await _client.delete('/doctors/me/photo');
    return body['photoUrl'] as String?;
  }

  @override
  Future<List<DoctorPatient>> fetchPatients({
    String? search,
    int limit = 50,
  }) async {
    final query = [
      'limit=$limit',
      if (search != null && search.trim().isNotEmpty)
        'search=${Uri.encodeQueryComponent(search.trim())}',
    ].join('&');

    final body = await _client.get('/doctors/me/patients?$query');

    final rows = body['patients'];
    if (rows is! List) return const [];

    return [
      for (final row in rows.whereType<Map<String, Object?>>())
        if (row['id'] is String)
          DoctorPatient(
            id: row['id'] as String,
            name: row['name'] as String? ?? 'Patient',
            consultations: (row['consultations'] as num?)?.toInt() ?? 0,
            lastConsultedAt:
                DateTime.tryParse(row['lastConsultedAt'] as String? ?? '') ??
                DateTime.now(),
            lastMode: row['lastMode'] == 'audio'
                ? ConsultationMode.audio
                : ConsultationMode.video,
            billed: (row['billed'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  @override
  Future<DoctorPatientDetail> fetchPatientDetail(String patientId) async {
    final body = await _client.get('/doctors/me/patients/$patientId');

    final patient = body['patient'];
    if (patient is! Map<String, Object?>) throw const Failure.unexpected();

    return DoctorPatientDetail(
      patient: DoctorPatient(
        id: patient['id'] as String? ?? patientId,
        name: patient['name'] as String? ?? 'Patient',
        consultations: (patient['consultations'] as num?)?.toInt() ?? 0,
        lastConsultedAt:
            DateTime.tryParse(
              patient['lastConsultedAt'] as String? ?? '',
            )?.toLocal() ??
            DateTime.now(),
        lastMode: patient['lastMode'] == 'audio'
            ? ConsultationMode.audio
            : ConsultationMode.video,
        billed: (patient['billed'] as num?)?.toInt() ?? 0,
      ),
      history: _entriesFrom(body['entries']),
    );
  }

  @override
  Future<List<DoctorReview>> fetchReviews({int limit = 50}) async {
    final body = await _client.get('/doctors/me/reviews?limit=$limit');

    final rows = body['reviews'];
    if (rows is! List) return const [];

    return [
      for (final row in rows.whereType<Map<String, Object?>>())
        if (row['id'] is String)
          DoctorReview(
            id: row['id'] as String,
            rating: (row['rating'] as num?)?.toInt() ?? 0,
            comment: (row['comment'] as String? ?? '').trim(),
            authorName: switch (row['authorName']) {
              final String name when name.trim().isNotEmpty => name.trim(),
              _ => 'Patient',
            },
            isAnonymous: row['isAnonymous'] == true,
            // Trusted from the server rather than decided here: whether a
            // reviewer's face may be shown is the API's call, and it withholds
            // the path on an anonymous review for the same reason it withholds
            // the name.
            photoUrl: switch (row['photoUrl']) {
              final String path when path.isNotEmpty => path,
              _ => null,
            },
            mode: row['mode'] == 'audio'
                ? ConsultationMode.audio
                : ConsultationMode.video,
            createdAt:
                DateTime.tryParse(
                  row['createdAt'] as String? ?? '',
                )?.toLocal() ??
                DateTime.now(),
          ),
    ];
  }

  @override
  Future<DoctorEarnings> fetchEarnings(EarningsPeriod period) async {
    final body = await _client.get(
      '/doctors/me/earnings?period=${period.query}',
    );

    final earnings = body['earnings'];
    if (earnings is! Map<String, Object?>) {
      return DoctorEarnings(period: period);
    }

    return DoctorEarnings(
      // The period the app asked for, not one parsed back. The server echoes
      // it, and a mismatch would only ever be a bug in one of the two.
      period: period,
      gross: (earnings['gross'] as num?)?.toInt() ?? 0,
      consultations: (earnings['consultations'] as num?)?.toInt() ?? 0,
      averageFee: (earnings['averageFee'] as num?)?.toInt() ?? 0,
      inFlight: (earnings['inFlight'] as num?)?.toInt() ?? 0,
      buckets: _bucketsFrom(earnings['buckets']),
      entries: _entriesFrom(earnings['entries']),
    );
  }

  @override
  Future<BankAccountSummary> fetchBankAccount() async {
    final body = await _client.get('/doctors/me/bank-account');
    return _bankFrom(body['bankAccount']);
  }

  @override
  Future<BankAccountSummary> saveBankAccount(BankAccount account) async {
    // PUT: an account is one destination, and merging half a new account over
    // half an old one is how money goes to the wrong place.
    final body = await _client.put(
      '/doctors/me/bank-account',
      body: {
        'bankName': account.bankName.trim(),
        'accountHolderName': account.accountHolderName.trim(),
        'accountNumber': account.accountNumber.trim(),
        'routingCode': account.routingCode.trim().toUpperCase(),
        'upiId': account.upiId.trim().isEmpty ? null : account.upiId.trim(),
      },
    );

    return _bankFrom(body['bankAccount']);
  }

  @override
  Future<List<DoctorCredential>> fetchCredentials() async {
    final body = await _client.get('/doctors/me/documents');

    final rows = body['documents'];
    if (rows is! List) return const [];

    return [
      for (final row in rows.whereType<Map<String, Object?>>())
        if (row['id'] is String) _credentialFrom(row),
    ];
  }

  @override
  Future<DoctorCredential> addCertificate({
    required String title,
    required String filePath,
    required String contentType,
  }) async {
    final body = await _client.uploadFile(
      '/doctors/me/certificates',
      field: 'certificate',
      filePath: filePath,
      // Declared explicitly. With nothing given the part is labelled
      // `application/octet-stream`, which is not on the API's allowlist — the
      // upload then fails in a way that reads as the file being wrong rather
      // than the header being missing.
      contentType: contentType,
      fields: {'title': title},
    );

    final row = body['document'];
    if (row is! Map<String, Object?> || row['id'] is! String) {
      throw const Failure('Your certificate could not be added.');
    }

    return _credentialFrom(row);
  }

  @override
  Future<void> removeCertificate(String id) async {
    await _client.delete('/doctors/me/certificates/${Uri.encodeComponent(id)}');
  }

  static DoctorCredential _credentialFrom(Map<String, Object?> row) {
    return DoctorCredential(
      id: row['id'] as String,
      type: CredentialType.from(row['type'] as String?),
      title: switch (row['title']) {
        final String text when text.trim().isNotEmpty => text.trim(),
        _ => null,
      },
      fileName: row['fileName'] as String? ?? 'document',
      sizeBytes: (row['sizeBytes'] as num?)?.toInt() ?? 0,
      mimeType: switch (row['mimeType']) {
        final String type when type.trim().isNotEmpty => type.trim(),
        _ => 'application/octet-stream',
      },
      uploadedAt:
          DateTime.tryParse(row['uploadedAt'] as String? ?? '') ??
          DateTime.now(),
      decision: CredentialDecision.from(row['decision'] as String?),
      note: row['note'] as String?,
      reviewedAt: DateTime.tryParse(row['reviewedAt'] as String? ?? ''),
    );
  }

  @override
  Future<DoctorSettings> fetchSettings() async {
    final body = await _client.get('/doctors/me/settings');
    return _settingsFrom(body['settings']);
  }

  @override
  Future<DoctorSettings> updateSettings(Map<String, Object?> payload) async {
    final body = await _client.patch('/doctors/me/settings', body: payload);
    return _settingsFrom(body['settings']);
  }

  static DoctorPracticeProfile _profileFrom(Object? value) {
    if (value is! Map<String, Object?>) {
      // A doctor with no record yet. The API creates one on first read, so this
      // is only reachable if the body is malformed — the screen opens on its
      // empty state rather than throwing.
      return const DoctorPracticeProfile(
        id: '',
        fullName: '',
        displayName: 'Your profile',
        status: 'draft',
      );
    }

    final fees = value['fees'];
    final rating = value['rating'];

    return DoctorPracticeProfile(
      id: value['id'] as String? ?? '',
      fullName: value['fullName'] as String? ?? '',
      displayName: value['displayName'] as String? ?? 'Your profile',
      status: value['status'] as String? ?? 'draft',
      phone: value['phone'] as String?,
      email: value['email'] as String?,
      medicalDegree: value['medicalDegree'] as String?,
      registrationNumber: value['registrationNumber'] as String?,
      specialty: value['specialty'] as String?,
      state: value['state'] as String?,
      city: value['city'] as String?,
      yearsOfExperience: (value['yearsOfExperience'] as num?)?.toInt(),
      bio: value['bio'] as String?,
      languages: value['languages'] is List
          ? (value['languages'] as List).whereType<String>().toList()
          : const [],
      photoUrl: value['photoUrl'] as String?,
      rejectionReason: value['rejectionReason'] as String?,
      submittedAt: DateTime.tryParse(value['submittedAt'] as String? ?? ''),
      videoFee: fees is Map<String, Object?>
          ? (fees['video'] as num?)?.toInt()
          : null,
      audioFee: fees is Map<String, Object?>
          ? (fees['audio'] as num?)?.toInt()
          : null,
      availability: _availabilityFrom(value['availability']),
      ratingAverage: rating is Map<String, Object?>
          ? (rating['average'] as num?)?.toDouble() ?? 0
          : 0,
      ratingCount: rating is Map<String, Object?>
          ? (rating['count'] as num?)?.toInt() ?? 0
          : 0,
      hasCertificate: value['hasCertificate'] == true,
    );
  }

  /// The schedule, in the shape the availability screen already speaks.
  ///
  /// Minutes since midnight on the wire, `ClockTime` in the app — the same
  /// conversion `ApiDoctorOnboardingRemoteDataSource` does, because the API
  /// serves one representation and two screens read it.
  static DoctorAvailability _availabilityFrom(Object? value) {
    if (value is! Map<String, Object?>) return const DoctorAvailability();

    final days = value['days'];
    final slots = value['slots'];

    return DoctorAvailability(
      isOnline: value['isOnline'] == true,
      days: days is List
          ? days.whereType<String>().map(_weekdayOf).nonNulls.toSet()
          : const {},
      slots: slots is List
          ? slots
                .whereType<Map<String, Object?>>()
                .map(_slotOf)
                .nonNulls
                .toSet()
          : const {},
    );
  }

  static Weekday? _weekdayOf(String name) {
    for (final day in Weekday.values) {
      if (day.name == name) return day;
    }
    return null;
  }

  static AvailabilitySlot? _slotOf(Map<String, Object?> json) {
    final start = (json['startMinute'] as num?)?.toInt();
    final end = (json['endMinute'] as num?)?.toInt();
    if (start == null || end == null) return null;

    return AvailabilitySlot(
      start: ClockTime(hour: start ~/ 60, minute: start % 60),
      end: ClockTime(hour: end ~/ 60, minute: end % 60),
    );
  }

  static List<EarningsBucket> _bucketsFrom(Object? value) {
    if (value is! List) return const [];

    return [
      for (final row in value.whereType<Map<String, Object?>>())
        if (row['key'] is String)
          EarningsBucket(
            key: row['key'] as String,
            gross: (row['gross'] as num?)?.toInt() ?? 0,
            consultations: (row['consultations'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  static List<EarningsEntry> _entriesFrom(Object? value) {
    if (value is! List) return const [];

    return [
      for (final row in value.whereType<Map<String, Object?>>())
        if (row['id'] is String)
          EarningsEntry(
            id: row['id'] as String,
            patientName: row['patientName'] as String? ?? 'Patient',
            mode: row['mode'] == 'audio'
                ? ConsultationMode.audio
                : ConsultationMode.video,
            endedAt:
                DateTime.tryParse(row['endedAt'] as String? ?? '') ??
                DateTime.now(),
            fee: (row['fee'] as num?)?.toInt() ?? 0,
            durationSeconds: (row['durationSeconds'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  static BankAccountSummary _bankFrom(Object? value) {
    if (value is! Map<String, Object?>) return const BankAccountSummary.none();

    return BankAccountSummary(
      isSet: value['isSet'] == true,
      bankName: value['bankName'] as String?,
      accountHolderName: value['accountHolderName'] as String?,
      accountNumberMasked: value['accountNumberMasked'] as String?,
      routingCode: value['routingCode'] as String?,
      upiId: value['upiId'] as String?,
    );
  }

  static DoctorSettings _settingsFrom(Object? value) {
    if (value is! Map<String, Object?>) return const DoctorSettings();

    return DoctorSettings(
      // `!= false` rather than `== true`, so a field the server has not started
      // sending yet keeps its default rather than reading as switched off —
      // which for `newConsultations` would silently take a doctor off the rota.
      newConsultations: value['newConsultations'] != false,
      chatMessages: value['chatMessages'] != false,
      payouts: value['payouts'] != false,
      platformUpdates: value['platformUpdates'] == true,
    );
  }

  static String? _contentTypeOf(String path) {
    final extension = path.split('.').last.toLowerCase();

    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => null,
    };
  }
}
