import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../../../core/logging/auth_logger.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/bank_account.dart';
import '../../domain/entities/doctor_application.dart';
import '../../domain/entities/doctor_availability.dart';
import '../../domain/entities/doctor_credentials.dart';
import '../../domain/entities/doctor_setup_options.dart';
import '../../domain/entities/medical_certificate.dart';
import '../../domain/entities/practice_setup.dart';
import 'doctor_onboarding_remote_data_source.dart';

/// Doctor registration, on the consultation API.
///
/// Replaces the Supabase implementation. Two things it used to rely on are now
/// the API's job rather than the database's: the storage-policy trick of keying
/// a certificate under `<uid>/` so a doctor can only write inside their own
/// folder, and the trigger that let only an administrator move the review
/// fields. Both are guards on the server now — the app sends a bearer token and
/// never names another doctor.
///
/// | Method | Path                             |
/// | ------ | -------------------------------- |
/// | POST   | /doctors/me/certificate          | multipart, one file
/// | POST   | /doctors/me/application          |
/// | GET    | /doctors/me/application          |
/// | GET    | /doctors/applications/:id        | polled while waiting
/// | GET    | /doctors/me/practice-setup       |
/// | PATCH  | /doctors/me/fee                  |
/// | GET    | /doctors/me/availability         |
/// | PUT    | /doctors/me/availability         |
class ApiDoctorOnboardingRemoteDataSource
    implements DoctorOnboardingRemoteDataSource {
  const ApiDoctorOnboardingRemoteDataSource(this._client);

  final ApiClient _client;

  /// How often the review is re-checked while the doctor waits.
  ///
  /// Polling rather than a socket: an approval arrives minutes or hours later,
  /// and a connection held open across that costs more than a request every
  /// few seconds does. Unchanged from the Supabase implementation.
  static const Duration reviewPollInterval = Duration(seconds: 5);

  // --- Setup options --------------------------------------------------------

  @override
  Future<DoctorSetupOptions> fetchSetupOptions() {
    // Static, as it was before: degrees, specialities and cities are reference
    // data that does not change per install. Moves to a `/reference-data`
    // endpoint when an administrator needs to edit them without a new build.
    return FakeDoctorOnboardingRemoteDataSource().fetchSetupOptions();
  }

  // --- Certificate ----------------------------------------------------------

  @override
  Future<DoctorCredentials> parseCertificate(
    MedicalCertificate certificate,
  ) async {
    // Deliberately empty, as before. Extraction from the range of council
    // certificates in use is unreliable, and a wrong prefill on credentials
    // that get legally verified is worse than none — the doctor fills the form
    // and the reviewer checks it against the uploaded file.
    return const DoctorCredentials();
  }

  /// Uploads the file and returns the object path the API stored it under.
  ///
  /// The path is the server's to choose. The app sending one is what the old
  /// storage policy had to defend against; not sending one removes the question.
  Future<String> _uploadCertificate(MedicalCertificate certificate) async {
    if (!certificate.isUploadable) {
      throw const Failure('That file could not be read. Try again.');
    }

    AuthLogger.event('API · uploading certificate', {
      'name': certificate.fileName,
      'size': certificate.sizeLabel,
      'type': certificate.mimeType,
      'source': certificate.source.name,
    });

    final body = await _client.uploadFile(
      '/doctors/me/certificate',
      field: 'certificate',
      filePath: certificate.localPath!,
      // Not optional. The API checks this header against a four-entry allowlist
      // and `MultipartFile` would otherwise declare `application/octet-stream`,
      // which is not on it — the upload comes back as "Upload a PDF or a
      // photo" for a file that is already a PDF. It is also the type stored
      // against the document, and therefore what decides whether the review
      // console can show it inline.
      contentType: certificate.mimeType,
      fields: {'source': certificate.source.name},
    );

    final path = body['path'];
    if (path is! String || path.isEmpty) {
      throw const Failure('Your certificate could not be uploaded.');
    }

    return path;
  }

  // --- Application ----------------------------------------------------------

  @override
  Future<DoctorApplication> submitApplication({
    required DoctorCredentials credentials,
    required BankAccount bankAccount,
    MedicalCertificate? certificate,
  }) async {
    final certificatePath = certificate == null
        ? null
        : await _uploadCertificate(certificate);

    final body = await _client.post(
      '/doctors/me/application',
      body: {
        'fullName': credentials.fullName.trim(),
        'medicalDegree': credentials.medicalDegree,
        'registrationNumber': credentials.registrationNumber.trim(),
        'specialty': credentials.specialty,
        'state': credentials.state,
        'city': credentials.city,
        'yearsOfExperience': credentials.yearsOfExperience,
        'verifiedFields': credentials.verifiedFields
            .map((field) => field.name)
            .toList(),
        if (certificate != null)
          'certificate': {
            'path': certificatePath,
            'name': certificate.fileName,
            'sizeBytes': certificate.sizeBytes,
            'source': certificate.source.name,
          },
        // Sent as a nested object, and stored by the API in its own collection:
        // the account number must not come back with an ordinary read of the
        // doctor's profile, which administrators can see.
        'bankAccount': {
          'bankName': bankAccount.bankName.trim(),
          'accountHolderName': bankAccount.accountHolderName.trim(),
          'accountNumber': bankAccount.accountNumber.trim(),
          'routingCode': bankAccount.routingCode.trim().toUpperCase(),
          'upiId': bankAccount.upiId.trim().isEmpty
              ? null
              : bankAccount.upiId.trim(),
        },
      },
    );

    AuthLogger.event('API · application submitted', {
      'certificate': certificatePath ?? '(none — filled by hand)',
    });

    final application = _applicationFrom(body['application']);
    if (application == null) throw const Failure.unexpected();

    return application;
  }

  @override
  Future<DoctorApplication?> fetchMyApplication() async {
    try {
      final body = await _client.get('/doctors/me/application');

      final application = _applicationFrom(body['application']);

      // A draft counts as no application: nothing was filed, so the doctor
      // belongs back on the form rather than on a waiting screen.
      if (application == null ||
          application.status == DoctorApplicationStatus.draft) {
        return null;
      }

      return application;
    } on Failure catch (failure) {
      if (failure.isNotFound) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Stream<DoctorApplication> watchApplication(String applicationId) {
    late final StreamController<DoctorApplication> controller;
    Timer? timer;
    var closed = false;

    Future<void> poll() async {
      try {
        final application = await _readApplication(applicationId);
        if (closed) return;

        controller.add(application);

        // Approved or rejected is the end of the wait; nothing further changes.
        if (application.isApproved || application.isRejected) {
          timer?.cancel();
          await controller.close();
        }
      } catch (error) {
        if (!closed) controller.addError(error);
      }
    }

    controller = StreamController<DoctorApplication>(
      onListen: () {
        poll();
        timer = Timer.periodic(reviewPollInterval, (_) => poll());
      },
      onCancel: () {
        closed = true;
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  Future<DoctorApplication> _readApplication(String id) async {
    final body = await _client.get(
      '/doctors/applications/${Uri.encodeComponent(id)}',
    );

    final application = _applicationFrom(body['application']);
    if (application == null) {
      throw const Failure('That application no longer exists.');
    }

    return application;
  }

  static DoctorApplication? _applicationFrom(Object? value) {
    if (value is! Map<String, Object?>) return null;

    final id = value['id'];
    if (id is! String || id.isEmpty) return null;

    final submittedAt = value['submittedAt'] as String?;

    return DoctorApplication(
      id: id,
      status: _statusFrom(value['status'] as String?),
      submittedAt: submittedAt == null ? null : DateTime.tryParse(submittedAt),
      rejectionReason: value['rejectionReason'] as String?,
    );
  }

  static DoctorApplicationStatus _statusFrom(String? value) {
    return switch (value) {
      'under_review' => DoctorApplicationStatus.underReview,
      'approved' => DoctorApplicationStatus.approved,
      'rejected' => DoctorApplicationStatus.rejected,
      _ => DoctorApplicationStatus.draft,
    };
  }

  // --- Practice setup -------------------------------------------------------

  @override
  Future<PracticeSetup> fetchPracticeSetup() async {
    final body = await _client.get('/doctors/me/practice-setup');

    return PracticeSetup(
      // Both null until the doctor prices them, and left null rather than
      // defaulted to the platform's suggestion: a default in the record is
      // indistinguishable from a price somebody chose. The *form* seeds the
      // suggestion, which is a different thing — see `PracticeSetup.videoFee`.
      videoFee: (body['videoFee'] as num?)?.toInt(),
      audioFee: (body['audioFee'] as num?)?.toInt(),
      percentComplete: 60,
    );
  }

  @override
  Future<void> saveConsultationFees({int? videoFee, int? audioFee}) async {
    // Only what was set. A key left out means "leave it alone" on the API, so
    // an audio-only edit does not overwrite the video price — and sending
    // `null` is refused there rather than storing an unpriced consultation,
    // which is why absent and null are kept apart here too.
    await _client.patch(
      '/doctors/me/fee',
      body: {'videoFee': ?videoFee, 'audioFee': ?audioFee},
    );
  }

  // --- Availability ---------------------------------------------------------

  @override
  Future<DoctorAvailability> fetchAvailability() async {
    final body = await _client.get('/doctors/me/availability');

    final availability = body['availability'];
    if (availability is! Map<String, Object?>) {
      // Never set one up — the screen opens on its defaults.
      return const DoctorAvailability();
    }

    return DoctorAvailability(
      isOnline: availability['isOnline'] == true,
      days: _daysFrom(availability['days']),
      slots: _slotsFrom(availability['slots']),
    );
  }

  @override
  Future<void> saveAvailability(DoctorAvailability availability) async {
    // PUT, not PATCH: the screen sends the whole schedule, so a window the
    // doctor removed has to actually disappear rather than being merged back.
    await _client.put(
      '/doctors/me/availability',
      body: {
        'isOnline': availability.isOnline,
        'days': availability.days.map((day) => day.name).toList(),
        'slots': [
          for (final slot in availability.slots)
            {
              'startMinute': slot.start.minutesSinceMidnight,
              'endMinute': slot.end.minutesSinceMidnight,
            },
        ],
      },
    );
  }

  static Set<Weekday> _daysFrom(Object? value) {
    if (value is! List) return const {};

    return {
      for (final day in value)
        ...Weekday.values.where((weekday) => weekday.name == day),
    };
  }

  static Set<AvailabilitySlot> _slotsFrom(Object? value) {
    if (value is! List) return const {};

    return {
      for (final slot in value.whereType<Map<String, Object?>>())
        if (slot['startMinute'] is num && slot['endMinute'] is num)
          AvailabilitySlot(
            start: _clockFrom((slot['startMinute'] as num).toInt()),
            end: _clockFrom((slot['endMinute'] as num).toInt()),
          ),
    };
  }

  static ClockTime _clockFrom(int minutes) =>
      ClockTime(hour: minutes ~/ 60, minute: minutes % 60);
}
