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
import 'doctor_practice_remote_data_source.dart';

/// Sample practice data, for a build with no backend.
///
/// Holds its edits for the run rather than answering with constants: saving a
/// profile and reading it back has to agree, or the form is untestable without
/// an API — which is the whole point of having a stub.
class FakeDoctorPracticeRemoteDataSource
    implements DoctorPracticeRemoteDataSource {
  FakeDoctorPracticeRemoteDataSource();

  DoctorPracticeProfile _profile = DoctorPracticeProfile(
    id: 'doctor-1',
    fullName: 'Amit Verma',
    displayName: 'Dr. Amit Verma',
    status: 'approved',
    phone: '+91 98765 43210',
    email: 'amit.verma@example.com',
    medicalDegree: 'MBBS, MD (Cardiology)',
    registrationNumber: 'MMC/2011/45821',
    specialty: 'Cardiologist',
    state: 'Maharashtra',
    city: 'Mumbai',
    yearsOfExperience: 15,
    bio: 'Consultant cardiologist with a focus on preventive care.',
    languages: const ['English', 'Hindi', 'Marathi'],
    submittedAt: DateTime(2026, 8, 2),
    videoFee: 700,
    audioFee: 500,
    availability: DoctorAvailability(
      isOnline: true,
      days: Weekday.workingWeek,
      slots: {
        const AvailabilitySlot(
          start: ClockTime(hour: 9, minute: 0),
          end: ClockTime(hour: 10, minute: 0),
        ),
        const AvailabilitySlot(
          start: ClockTime(hour: 14, minute: 0),
          end: ClockTime(hour: 15, minute: 0),
        ),
      },
    ),
    ratingAverage: 4.8,
    ratingCount: 36,
    hasCertificate: true,
  );

  DoctorSettings _settings = const DoctorSettings();

  BankAccountSummary _bank = const BankAccountSummary(
    isSet: true,
    bankName: 'HDFC Bank',
    accountHolderName: 'Amit Verma',
    accountNumberMasked: '•••• 6789',
    routingCode: 'HDFC0000123',
    upiId: 'amitverma@okhdfcbank',
  );

  @override
  Future<DoctorPracticeProfile> fetchProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return _profile;
  }

  @override
  Future<DoctorPracticeProfile> updateProfile(
    Map<String, Object?> payload,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final fullName =
        (payload['fullName'] as String?)?.trim() ?? _profile.fullName;

    _profile = DoctorPracticeProfile(
      id: _profile.id,
      fullName: fullName,
      // The title is added on the way out by the API, and the stub does the
      // same so the header does not lose it after an edit.
      displayName: RegExp(r'^dr\.?\s', caseSensitive: false).hasMatch(fullName)
          ? fullName
          : 'Dr. $fullName',
      status: _profile.status,
      phone: _profile.phone,
      email: payload['email'] as String?,
      medicalDegree: _profile.medicalDegree,
      registrationNumber: _profile.registrationNumber,
      specialty: _profile.specialty,
      state: payload['state'] as String?,
      city: payload['city'] as String?,
      yearsOfExperience: (payload['yearsOfExperience'] as num?)?.toInt(),
      bio: payload['bio'] as String?,
      languages: payload['languages'] is List
          ? (payload['languages'] as List).whereType<String>().toList()
          : _profile.languages,
      photoUrl: _profile.photoUrl,
      rejectionReason: _profile.rejectionReason,
      submittedAt: _profile.submittedAt,
      videoFee: _profile.videoFee,
      audioFee: _profile.audioFee,
      availability: _profile.availability,
      ratingAverage: _profile.ratingAverage,
      ratingCount: _profile.ratingCount,
      hasCertificate: _profile.hasCertificate,
    );

    return _profile;
  }

  @override
  Future<String?> uploadPhoto(String filePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _profile = _profile.copyWith(photoUrl: filePath);
    return filePath;
  }

  @override
  Future<String?> removePhoto() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _profile = _profile.copyWith(clearPhoto: true);
    return null;
  }

  @override
  Future<List<DoctorPatient>> fetchPatients({
    String? search,
    int limit = 50,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final now = DateTime.now();

    final patients = [
      DoctorPatient(
        id: 'patient-1',
        name: 'Rahul Sharma',
        consultations: 4,
        lastConsultedAt: now.subtract(const Duration(days: 2)),
        lastMode: ConsultationMode.video,
        billed: 2800,
      ),
      DoctorPatient(
        id: 'patient-2',
        name: 'Meera Iyer',
        consultations: 2,
        lastConsultedAt: now.subtract(const Duration(days: 9)),
        lastMode: ConsultationMode.audio,
        billed: 1000,
      ),
      DoctorPatient(
        id: 'patient-3',
        name: 'Sanjay Gupta',
        consultations: 1,
        lastConsultedAt: now.subtract(const Duration(days: 21)),
        lastMode: ConsultationMode.video,
        billed: 700,
      ),
    ];

    final needle = search?.trim().toLowerCase();

    return patients
        .where(
          (patient) =>
              needle == null ||
              needle.isEmpty ||
              patient.name.toLowerCase().contains(needle),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<DoctorPatientDetail> fetchPatientDetail(String patientId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final patients = await fetchPatients();
    final patient = patients.firstWhere(
      (row) => row.id == patientId,
      orElse: () => patients.first,
    );

    final now = DateTime.now();

    return DoctorPatientDetail(
      patient: patient,
      history: [
        for (var visit = 0; visit < patient.consultations; visit++)
          EarningsEntry(
            id: '${patient.id}-visit-$visit',
            patientName: patient.name,
            mode: patient.lastMode,
            endedAt: now.subtract(Duration(days: 2 + visit * 26)),
            fee: 700,
            durationSeconds: 720,
          ),
      ],
    );
  }

  @override
  Future<List<DoctorReview>> fetchReviews({int limit = 50}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final now = DateTime.now();

    // One anonymous row on purpose: the name and the photo are both withheld
    // there, and a stub with only named reviews would render the one case the
    // screen has to get right zero times.
    return [
      DoctorReview(
        id: 'review-1',
        rating: 5,
        comment: 'Explained everything clearly and did not rush me.',
        authorName: 'Rahul Sharma',
        mode: ConsultationMode.video,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      DoctorReview(
        id: 'review-2',
        rating: 4,
        comment: 'Call quality dropped once but the advice was sound.',
        authorName: 'Anonymous user',
        isAnonymous: true,
        mode: ConsultationMode.audio,
        createdAt: now.subtract(const Duration(days: 9)),
      ),
      DoctorReview(
        id: 'review-3',
        rating: 5,
        comment: 'Followed up the next day to check how I was doing.',
        authorName: 'Meera Iyer',
        mode: ConsultationMode.video,
        createdAt: now.subtract(const Duration(days: 23)),
      ),
    ].take(limit).toList();
  }

  @override
  Future<DoctorEarnings> fetchEarnings(EarningsPeriod period) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final now = DateTime.now();

    // A week of plausible days, with two quiet ones — a chart that is flat
    // everywhere hides the bug where every bar renders the same height.
    final grosses = [700, 0, 1400, 700, 2100, 0, 1400];

    final buckets = [
      for (final (index, gross) in grosses.indexed)
        EarningsBucket(
          key: _dayKey(now.subtract(Duration(days: 6 - index))),
          gross: gross,
          consultations: gross ~/ 700,
        ),
    ];

    final entries = [
      for (var index = 0; index < 5; index += 1)
        EarningsEntry(
          id: 'earning-$index',
          patientName: index.isEven ? 'Rahul Sharma' : 'Meera Iyer',
          mode: index.isEven ? ConsultationMode.video : ConsultationMode.audio,
          endedAt: now.subtract(Duration(days: index, hours: 2)),
          fee: index.isEven ? 700 : 500,
          durationSeconds: 480 + index * 60,
        ),
    ];

    final gross = buckets.fold(0, (total, bucket) => total + bucket.gross);
    final consultations = buckets.fold(
      0,
      (total, bucket) => total + bucket.consultations,
    );

    return DoctorEarnings(
      period: period,
      gross: gross,
      consultations: consultations,
      averageFee: consultations == 0 ? 0 : (gross / consultations).round(),
      inFlight: 1,
      buckets: buckets,
      entries: entries,
    );
  }

  @override
  Future<BankAccountSummary> fetchBankAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _bank;
  }

  @override
  Future<BankAccountSummary> saveBankAccount(BankAccount account) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    _bank = BankAccountSummary(
      isSet: true,
      bankName: account.bankName.trim(),
      accountHolderName: account.accountHolderName.trim(),
      // Masked on the way back, as the API does: nothing above the data layer
      // should ever hold the whole number again once it has been sent.
      accountNumberMasked: account.maskedAccountNumber,
      routingCode: account.routingCode.trim().toUpperCase(),
      upiId: account.upiId.trim().isEmpty ? null : account.upiId.trim(),
    );

    return _bank;
  }

  @override
  Future<List<DoctorCredential>> fetchCredentials() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    return [
      DoctorCredential(
        id: 'document-1',
        type: CredentialType.degree,
        fileName: 'mbbs-degree.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 1_482_000,
        uploadedAt: DateTime(2026, 8, 2),
        decision: CredentialDecision.accepted,
        reviewedAt: DateTime(2026, 8, 4),
      ),
      // Held in memory so the offline build exercises both states of an added
      // certificate — one waiting on a reviewer, one already on the profile.
      ..._certificates,
    ];
  }

  /// Certificates added during this run. Not persisted: the stub exists so a
  /// device with no backend can drive the screens, and a fake that survived a
  /// restart would be a database nobody asked for.
  final List<DoctorCredential> _certificates = [
    DoctorCredential(
      id: 'document-2',
      type: CredentialType.certificate,
      title: 'Fellowship in Interventional Cardiology',
      fileName: 'fellowship.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 890_000,
      uploadedAt: DateTime(2026, 9, 1),
    ),
  ];

  @override
  Future<DoctorCredential> addCertificate({
    required String title,
    required String filePath,
    required String contentType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final added = DoctorCredential(
      id: 'document-${DateTime.now().microsecondsSinceEpoch}',
      type: CredentialType.certificate,
      title: title,
      fileName: _baseName(filePath),
      sizeBytes: 512_000,
      uploadedAt: DateTime.now(),
    );

    _certificates.add(added);
    return added;
  }

  @override
  Future<void> removeCertificate(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _certificates.removeWhere((certificate) => certificate.id == id);
  }

  @override
  Future<DoctorSettings> fetchSettings() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _settings;
  }

  @override
  Future<DoctorSettings> updateSettings(Map<String, Object?> payload) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    for (final toggle in DoctorNotificationToggle.values) {
      if (payload[toggle.name] case final bool value) {
        _settings = toggle.applyTo(_settings, value);
      }
    }

    return _settings;
  }

  static String _dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

/// The last segment of a path, whichever separator the platform used.
///
/// Hand-rolled rather than a regex over a character class containing a
/// backslash, which is unreadable in Dart however it is quoted.
String _baseName(String path) {
  final slash = path.lastIndexOf(String.fromCharCode(47));
  final backslash = path.lastIndexOf(String.fromCharCode(92));
  final cut = slash > backslash ? slash : backslash;

  return cut == -1 ? path : path.substring(cut + 1);
}
