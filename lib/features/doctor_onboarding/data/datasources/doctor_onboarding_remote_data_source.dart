import 'dart:async';

import '../../../../core/constants/india_locations.dart';

import '../../domain/entities/bank_account.dart';
import '../../domain/entities/doctor_application.dart';
import '../../domain/entities/doctor_availability.dart';
import '../../domain/entities/doctor_credentials.dart';
import '../../domain/entities/doctor_setup_options.dart';
import '../../domain/entities/medical_certificate.dart';
import '../../domain/entities/practice_setup.dart';

/// Talks to the backend that registers and verifies doctors.
abstract interface class DoctorOnboardingRemoteDataSource {
  Future<DoctorSetupOptions> fetchSetupOptions();

  Future<DoctorCredentials> parseCertificate(MedicalCertificate certificate);

  Future<DoctorApplication> submitApplication({
    required DoctorCredentials credentials,
    required BankAccount bankAccount,
    MedicalCertificate? certificate,
  });

  /// The signed-in doctor's own registration, or null when they never filed
  /// one. Read at startup to resume them where they left off.
  Future<DoctorApplication?> fetchMyApplication();

  Stream<DoctorApplication> watchApplication(String applicationId);

  Future<PracticeSetup> fetchPracticeSetup();

  /// Either may be null, meaning "leave that one alone".
  Future<void> saveConsultationFees({int? videoFee, int? audioFee});

  Future<DoctorAvailability> fetchAvailability();

  Future<void> saveAvailability(DoctorAvailability availability);
}

/// Stand-in until the doctor registration service exists. Swap for an HTTP and
/// websocket implementation — nothing above this layer changes.
class FakeDoctorOnboardingRemoteDataSource
    implements DoctorOnboardingRemoteDataSource {
  FakeDoctorOnboardingRemoteDataSource();

  /// How long the stubbed board takes to approve a registration.
  static const Duration reviewDuration = Duration(seconds: 4);

  /// Held for the run, so saving a fee and reading it back agrees — which is
  /// what makes the fee screen usable with no backend.
  /// Starts with two *different* prices, deliberately. The stub used to hold
  /// one amount for both, which is exactly the thing that was wrong — a fake
  /// that cannot tell a video fee from an audio one hides a screen that has
  /// stopped telling them apart.
  PracticeSetup _setup = const PracticeSetup(
    videoFee: 700,
    audioFee: 400,
    percentComplete: 60,
  );
  DoctorAvailability? _availability;

  @override
  Future<DoctorSetupOptions> fetchSetupOptions() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    return const DoctorSetupOptions(
      degrees: [
        'MBBS',
        'MD - General Medicine',
        'MD - Paediatrics',
        'MS - General Surgery',
        'BDS',
        'MDS - Orthodontics',
      ],
      // The six the patient home screen has always shown come first, spelled
      // exactly as before: the directory filters on this string, so renaming
      // one would hide every doctor already registered under it. The rest are
      // alphabetical, and a doctor can still type one that is not here.
      specialities: [
        'Stress Management',
        'Internal Medicine',
        'Cardiology',
        'Paediatrics',
        'Dermatology',
        'Neurology',
        'Dentistry',
        'Allergy & Immunology',
        'Anaesthesiology',
        'Ayurveda',
        'Clinical Psychology',
        'Diabetology',
        'Dietetics & Nutrition',
        'Emergency Medicine',
        'Endocrinology',
        'ENT (Otorhinolaryngology)',
        'Family Medicine',
        'Gastroenterology',
        'General Physician',
        'General Surgery',
        'Geriatrics',
        'Gynaecology & Obstetrics',
        'Haematology',
        'Hepatology',
        'Homeopathy',
        'Infectious Diseases',
        'Nephrology',
        'Neurosurgery',
        'Oncology',
        'Ophthalmology',
        'Orthopaedics',
        'Pathology',
        'Physiotherapy',
        'Plastic Surgery',
        'Psychiatry',
        'Pulmonology',
        'Radiology',
        'Rheumatology',
        'Sexology',
        'Sports Medicine',
        'Trichology',
        'Urology',
        'Vascular Surgery',
      ],
      citiesByState: indiaCitiesByState,
      experienceYears: [1, 2, 3, 5, 8, 10, 12, 15, 20, 25],
    );
  }

  @override
  Future<DoctorCredentials> parseCertificate(
    MedicalCertificate certificate,
  ) async {
    // The parse is the slowest step in the flow — it is doing the reading.
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    return const DoctorCredentials(
      fullName: 'Dr. Sarah Jenkins',
      medicalDegree: 'MD - General Medicine',
      registrationNumber: 'REG-9920-A',
      specialty: 'Internal Medicine',
      state: 'Maharashtra',
      city: 'Mumbai',
      yearsOfExperience: 8,
      // The register confirmed everything but where they practise, which the
      // certificate does not state.
      verifiedFields: {
        DoctorCredentialField.fullName,
        DoctorCredentialField.medicalDegree,
        DoctorCredentialField.registrationNumber,
        DoctorCredentialField.specialty,
      },
    );
  }

  @override
  Future<DoctorApplication> submitApplication({
    required DoctorCredentials credentials,
    required BankAccount bankAccount,
    MedicalCertificate? certificate,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));

    return DoctorApplication(
      id: 'application-${DateTime.now().millisecondsSinceEpoch}',
      status: DoctorApplicationStatus.underReview,
      submittedAt: DateTime.now(),
    );
  }

  @override
  Future<DoctorApplication?> fetchMyApplication() async {
    // The stub has no persisted account, so a fresh run always starts before
    // any registration was filed.
    return null;
  }

  @override
  Stream<DoctorApplication> watchApplication(String applicationId) {
    // A timer rather than an awaited delay, so dropping the subscription
    // really does stop the watch.
    late final StreamController<DoctorApplication> controller;
    Timer? timer;

    controller = StreamController<DoctorApplication>(
      onListen: () {
        controller.add(
          DoctorApplication(
            id: applicationId,
            status: DoctorApplicationStatus.underReview,
            submittedAt: DateTime.now(),
          ),
        );

        timer = Timer(reviewDuration, () {
          controller.add(
            DoctorApplication(
              id: applicationId,
              status: DoctorApplicationStatus.approved,
              submittedAt: DateTime.now(),
            ),
          );
          controller.close();
        });
      },
      onCancel: () => timer?.cancel(),
    );

    return controller.stream;
  }

  @override
  Future<PracticeSetup> fetchPracticeSetup() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    return _setup;
  }

  @override
  Future<void> saveConsultationFees({int? videoFee, int? audioFee}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // Held for the run, so saving a fee and reading it back agrees — which is
    // what makes the screen usable with no backend.
    _setup = _setup.copyWith(
      videoFee: videoFee ?? _setup.videoFee,
      audioFee: audioFee ?? _setup.audioFee,
    );
  }

  @override
  Future<DoctorAvailability> fetchAvailability() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // A weekday schedule with three windows, matching what a new doctor is
    // offered by default. Not const: the slots define their own equality.
    return _availability ??
        DoctorAvailability(
          isOnline: true,
          days: const {
            Weekday.monday,
            Weekday.tuesday,
            Weekday.wednesday,
            Weekday.thursday,
            Weekday.friday,
          },
          slots: {
            AvailabilityPresets.hourly[0],
            AvailabilityPresets.hourly[1],
            AvailabilityPresets.hourly[4],
          },
        );
  }

  @override
  Future<void> saveAvailability(DoctorAvailability availability) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _availability = availability;
  }
}
