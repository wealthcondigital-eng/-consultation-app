import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/features/admin/domain/entities/doctor_review.dart';
import 'package:consultation_app/features/admin/domain/repositories/admin_repository.dart';
import 'package:consultation_app/features/admin/domain/usecases/is_admin.dart';
import 'package:consultation_app/features/auth/domain/entities/otp_code.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/bank_account.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/doctor_application.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/doctor_availability.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/doctor_credentials.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/doctor_setup_options.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/medical_certificate.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/practice_setup.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/repositories/doctor_onboarding_repository.dart';
import 'package:consultation_app/features/onboarding/domain/repositories/role_repository.dart';
import 'package:consultation_app/features/onboarding/domain/usecases/get_selected_role.dart';
import 'package:consultation_app/features/auth/domain/entities/phone_number.dart';
import 'package:consultation_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:consultation_app/features/onboarding/domain/entities/user_role.dart';
import 'package:consultation_app/features/profile/domain/entities/medical_history.dart';
import 'package:consultation_app/features/profile/domain/entities/medical_report.dart';
import 'package:consultation_app/features/profile/domain/entities/notification_settings.dart';
import 'package:consultation_app/features/profile/domain/entities/patient_account.dart';
import 'package:consultation_app/features/profile/domain/entities/patient_details.dart';
import 'package:consultation_app/features/profile/domain/entities/patient_profile.dart';
import 'package:consultation_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:consultation_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:consultation_app/features/startup/domain/entities/start_destination.dart';
import 'package:consultation_app/features/startup/domain/usecases/resolve_start_destination.dart';
import 'package:flutter_test/flutter_test.dart';

/// What `ApiClient` raises on a 401: not a transport error but the server
/// saying it does not know this account. The wording is the API's own.
const _expiredSession = Failure(
  'Please sign in again to continue.',
  code: Failure.sessionExpired,
);

class _StubAuthRepository implements AuthRepository {
  _StubAuthRepository({required this.isSignedIn});

  @override
  final bool isSignedIn;

  @override
  Future<OtpChallenge> requestOtp(PhoneNumber phoneNumber) async =>
      const OtpChallenge(verificationId: '');
  @override
  Future<void> verifyOtp({
    required String verificationId,
    required OtpCode code,
    String? role,
  }) async {}
  @override
  Future<void> signOut() async {}
}

class _StubProfileRepository implements ProfileRepository {
  _StubProfileRepository({
    this.exists = true,
    this.throws = false,
    this.expired = false,
  });

  final bool exists;
  final bool throws;

  /// The server answered 401, which is a different answer from "I could not
  /// reach it" and routes to a different place.
  final bool expired;

  @override
  Future<bool> hasProfile() async {
    if (expired) throw _expiredSession;
    if (throws) throw const Failure.network();
    return exists;
  }

  @override
  Future<PatientAccount> fetchAccount() async => throw UnimplementedError();
  @override
  Future<void> savePatientProfile(PatientProfile profile) async {}
  // Startup reads nothing but `hasProfile`. The rest is declared so the stub
  // satisfies the contract, and throws rather than answering — a startup path
  // that reached one of these would be a bug worth failing on.
  @override
  Future<MedicalHistory> fetchMedicalHistory() async =>
      throw UnimplementedError();
  @override
  Future<MedicalHistory> saveMedicalHistory(MedicalHistory history) async =>
      throw UnimplementedError();
  @override
  Future<NotificationSettings> fetchSettings() async =>
      throw UnimplementedError();
  @override
  Future<NotificationSettings> setNotificationPreference(
    PatientNotificationToggle toggle,
    bool value,
  ) async => throw UnimplementedError();
  @override
  Future<String?> uploadPhoto(String filePath) async =>
      throw UnimplementedError();
  @override
  Future<String?> removePhoto() async => throw UnimplementedError();
  @override
  Future<DateTime?> deleteAccount() async => throw UnimplementedError();
  @override
  Future<List<MedicalReport>> fetchReports() async =>
      throw UnimplementedError();
  @override
  Future<MedicalReport> uploadReport({
    required String filePath,
    required String title,
    MedicalRecordKind kind = MedicalRecordKind.report,
  }) async => throw UnimplementedError();
  @override
  Future<void> deleteReport(String id) async => throw UnimplementedError();
  @override
  Future<PatientAccount?> updateDetails(PatientDetails details) async => null;
}

class _StubAdminRepository implements AdminRepository {
  _StubAdminRepository({this.admin = false});

  final bool admin;

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Future<List<DoctorReview>> fetchPendingDoctors() async => const [];
  @override
  Future<void> approve(String doctorId) async {}
  @override
  Future<void> reject(String doctorId, String reason) async {}
  @override
  Future<String> certificateUrl(String storagePath) async => '';
}

class _StubDoctorRepository implements DoctorOnboardingRepository {
  _StubDoctorRepository({
    this.application,
    this.throws = false,
    this.expired = false,
    this.practiceSetup = const PracticeSetup(),
    this.practiceSetupThrows = false,
  });

  /// The fee read failing, which must not be read as "no fees set".
  final bool practiceSetupThrows;

  /// Fees, once the doctor has set them. An approved doctor with none is not
  /// bookable, and is sent to finish setting up rather than to a dashboard.
  final PracticeSetup practiceSetup;

  final DoctorApplication? application;
  final bool throws;

  /// The server answered 401, which is a different answer from "I could not
  /// reach it" and routes to a different place.
  final bool expired;

  @override
  Future<DoctorApplication?> fetchMyApplication() async {
    if (expired) throw _expiredSession;
    if (throws) throw const Failure.network();
    return application;
  }

  @override
  Future<DoctorSetupOptions> fetchSetupOptions() async =>
      throw UnimplementedError();
  @override
  Future<DoctorCredentials> parseCertificate(MedicalCertificate certificate) =>
      throw UnimplementedError();
  @override
  Future<DoctorApplication> submitApplication({
    required DoctorCredentials credentials,
    required BankAccount bankAccount,
    MedicalCertificate? certificate,
  }) => throw UnimplementedError();
  @override
  Stream<DoctorApplication> watchApplication(String applicationId) =>
      throw UnimplementedError();
  @override
  Future<PracticeSetup> fetchPracticeSetup() async {
    if (practiceSetupThrows) throw const Failure.network();
    return practiceSetup;
  }

  @override
  Future<void> saveConsultationFees({int? videoFee, int? audioFee}) =>
      throw UnimplementedError();
  @override
  Future<DoctorAvailability> fetchAvailability() => throw UnimplementedError();
  @override
  Future<void> saveAvailability(DoctorAvailability availability) =>
      throw UnimplementedError();
}

DoctorApplication _application(DoctorApplicationStatus status) =>
    DoctorApplication(id: 'doctor-1', status: status);

ResolveStartDestination _useCase({
  required bool signedIn,
  bool profileExists = true,
  bool profileThrows = false,
  bool profileExpired = false,
  bool isAdmin = false,
  DoctorApplication? application,
  bool doctorThrows = false,
  bool doctorExpired = false,

  /// The fees an approved doctor has already set, if any.
  PracticeSetup practiceSetup = const PracticeSetup(),
  bool practiceSetupThrows = false,

  /// The journey this person chose, as it survives a restart.
  UserRole? storedRole,
}) {
  return ResolveStartDestination(
    _StubAuthRepository(isSignedIn: signedIn),
    _StubProfileRepository(
      exists: profileExists,
      throws: profileThrows,
      expired: profileExpired,
    ),
    _StubDoctorRepository(
      application: application,
      throws: doctorThrows,
      expired: doctorExpired,
      practiceSetup: practiceSetup,
      practiceSetupThrows: practiceSetupThrows,
    ),
    IsAdmin(_StubAdminRepository(admin: isAdmin)),
    GetSelectedRole(_StubRoleRepository(role: storedRole)),
  );
}

class _StubRoleRepository implements RoleRepository {
  const _StubRoleRepository({this.role});

  final UserRole? role;

  @override
  Future<UserRole?> readSelectedRole() async => role;

  @override
  Future<void> saveSelectedRole(UserRole role) async {}

  @override
  Future<void> clearSelectedRole() async {}
}

void main() {
  group('ResolveStartDestination', () {
    test('sends a signed-out visitor to the landing screen', () async {
      final entry = await _useCase(signedIn: false)();
      expect(entry.destination, StartDestination.landing);
    });

    test('sends a returning patient straight to the dashboard', () async {
      final entry = await _useCase(signedIn: true)();
      expect(entry.destination, StartDestination.home);
    });

    test('sends a signed-in patient with no row back to onboarding', () async {
      final entry = await _useCase(
        signedIn: true,
        profileExists: false,
      ).forSignedInUser(role: UserRole.patient);

      expect(entry.destination, StartDestination.completeProfile);
    });

    test('sends an administrator to the review queue', () async {
      // Checked before the profile: a reviewer has no patient record, and
      // looking for one would send them to onboarding instead.
      final entry = await _useCase(
        signedIn: true,
        isAdmin: true,
        profileExists: false,
      )();

      expect(entry.destination, StartDestination.adminQueue);
    });

    test(
      'a signed-out administrator still starts at the landing screen',
      () async {
        final entry = await _useCase(signedIn: false, isAdmin: true)();
        expect(entry.destination, StartDestination.landing);
      },
    );

    test('keeps the session when the profile lookup fails', () async {
      // Losing the network is not a reason to make someone sign in again.
      final entry = await _useCase(signedIn: true, profileThrows: true)();
      expect(entry.destination, StartDestination.home);
    });
  });

  group('ResolveStartDestination · doctors', () {
    test(
      'a doctor under review waits, and never enters the patient flow',
      () async {
        // The bug this guards: a doctor has no `patients` row, so checking the
        // patient table first dropped them into patient onboarding.
        final entry = await _useCase(
          signedIn: true,
          profileExists: false,
          application: _application(DoctorApplicationStatus.underReview),
        )();

        expect(entry.destination, StartDestination.doctorPending);
        // The screen is built from it, so it has to travel with the decision.
        expect(entry.application, isNotNull);
      },
    );

    test('an approved doctor with a working practice opens on their own '
        'dashboard', () async {
      // The bug this guards: there was no doctor-home destination at all, so a
      // working doctor was sent to the congratulations screen on every launch
      // and had to re-run the practice wizard to reach their dashboard.
      final entry = await _useCase(
        signedIn: true,
        application: _application(DoctorApplicationStatus.approved),
        practiceSetup: const PracticeSetup(videoFee: 500, audioFee: 300),
      )();

      expect(entry.destination, StartDestination.doctorHome);
    });

    test('an approved doctor who has not priced a consultation is sent to '
        'finish setting up', () async {
      // Approval is not a working practice. With no fee there is nothing for a
      // patient to book, so the dashboard is a screen where nothing can happen
      // — and the approval screen is the one that leads to fees, then
      // availability.
      final entry = await _useCase(
        signedIn: true,
        application: _application(DoctorApplicationStatus.approved),
      )();

      expect(entry.destination, StartDestination.doctorApproved);
    });

    test('one fee is enough to be bookable', () async {
      // Audio-only is a practice, not a half-finished one.
      final entry = await _useCase(
        signedIn: true,
        application: _application(DoctorApplicationStatus.approved),
        practiceSetup: const PracticeSetup(audioFee: 300),
      )();

      expect(entry.destination, StartDestination.doctorHome);
    });

    test('a failed fee lookup does not push a set-up doctor back through the '
        'wizard', () async {
      // The dashboard carries its own retry. Reading one unanswered lookup as
      // "no fees" would send a working doctor round the setup screens every
      // time the network hiccuped.
      final entry = await _useCase(
        signedIn: true,
        application: _application(DoctorApplicationStatus.approved),
        practiceSetupThrows: true,
      )();

      expect(entry.destination, StartDestination.doctorHome);
    });

    test('an approved doctor is not sent to the patient app, even holding a '
        'patient row', () async {
      // The reported bug: restart, and the doctor was in the patient
      // dashboard. Someone can legitimately have both records.
      final entry = await _useCase(
        signedIn: true,
        profileExists: true,
        storedRole: UserRole.doctor,
        application: _application(DoctorApplicationStatus.approved),
        practiceSetup: const PracticeSetup(videoFee: 500),
      )();

      expect(entry.destination, StartDestination.doctorHome);
    });

    test('a doctor whose lookup fails is sent to the role choice, not the '
        'certificate form', () async {
      // Half of the reported bug: the doctor lookup swallowed its error and
      // returned null, which is indistinguishable from "not a doctor" — and
      // the patient check then answered true on *its* error too, so one bad
      // connection moved a doctor into the patient dashboard.
      //
      // The role choice, not the certificate form. That form was the old
      // fallback because it re-reads the application and moves a doctor on,
      // but its first screen asks for a medical certificate — so a registered
      // doctor whose lookup merely timed out was told to upload paperwork they
      // had already filed, on a screen with no way back. The session is kept,
      // so nothing here signs anybody out.
      final entry = await _useCase(
        signedIn: true,
        doctorThrows: true,
        profileThrows: true,
        storedRole: UserRole.doctor,
      )();

      expect(entry.destination, StartDestination.landing);
      expect(entry.notice, contains("couldn't confirm"));
    });

    test('a registered doctor cannot enter the patient app', () async {
      // A phone number is one person, and one person is either consulting or
      // being consulted. Without this the two journeys could both be entered
      // from the same number, leaving two half-built accounts on one identity.
      final entry = await _useCase(
        signedIn: true,
        application: const DoctorApplication(
          id: 'application-1',
          status: DoctorApplicationStatus.approved,
        ),
        storedRole: UserRole.patient,
      )();

      expect(entry.destination, StartDestination.roleConflict);
      expect(entry.notice, contains('already registered as a doctor'));
    });

    test('a registered patient cannot enter the doctor app', () async {
      final entry = await _useCase(
        signedIn: true,
        profileExists: true,
        storedRole: UserRole.doctor,
      )();

      expect(entry.destination, StartDestination.roleConflict);
      expect(entry.notice, contains('already registered as a patient'));
    });

    test('a failed patient lookup does not put a doctor on the certificate '
        'form', () async {
      // The conflict is only raised on an answer, never on a guess: the
      // patient lookup reports true when it *fails*, and treating that as a
      // registration would turn a flaky connection into a doctor refused
      // their own journey.
      //
      // It lands on the role choice rather than the certificate form. The form
      // asks for a medical certificate, so a doctor who filed one months ago
      // was told to upload it again by a lookup that never actually answered.
      final entry = await _useCase(
        signedIn: true,
        profileThrows: true,
        storedRole: UserRole.doctor,
      )();

      expect(entry.destination, StartDestination.landing);
      expect(entry.notice, contains("couldn't confirm"));
    });

    test(
      'a patient whose lookup fails still lands on the patient dashboard',
      () async {
        final entry = await _useCase(
          signedIn: true,
          doctorThrows: true,
          profileThrows: true,
          storedRole: UserRole.patient,
        )();

        expect(entry.destination, StartDestination.home);
      },
    );

    test('a rejected doctor goes back to the form to correct it', () async {
      final entry = await _useCase(
        signedIn: true,
        application: _application(DoctorApplicationStatus.rejected),
      )();

      expect(entry.destination, StartDestination.doctorSetup);
    });

    test('an application outranks an existing patient record', () async {
      // Someone who used the app as a patient and later applied is a doctor
      // now; the registration is the more recent intent.
      final entry = await _useCase(
        signedIn: true,
        profileExists: true,
        application: _application(DoctorApplicationStatus.underReview),
      )();

      expect(entry.destination, StartDestination.doctorPending);
    });

    test('a brand-new doctor with no application starts at setup', () async {
      final entry = await _useCase(
        signedIn: true,
        profileExists: false,
      ).forSignedInUser(role: UserRole.doctor);

      expect(entry.destination, StartDestination.doctorSetup);
    });
  });

  group('ResolveStartDestination when the server refuses the session', () {
    // The case a database reset creates, and the one no local check can catch:
    // the stored token is unexpired and well-formed, and the account it names
    // is gone. Every lookup comes back 401 and the app used to route on those
    // failures as though they were answers.

    test(
      'a doctor whose session is refused goes back to the role choice',
      () async {
        final entry = await _useCase(
          signedIn: true,
          doctorExpired: true,
          profileExpired: true,
          storedRole: UserRole.doctor,
        )();

        // Not doctorSetup. A doctor holding a dead token was walked into the
        // certificate upload form, which cannot save, cannot recover, and offers
        // no way back to the landing screen.
        expect(entry.destination, StartDestination.sessionExpired);
        expect(entry.notice, contains('sign in again'));
      },
    );

    test(
      'a patient whose session is refused goes back to the role choice',
      () async {
        final entry = await _useCase(
          signedIn: true,
          doctorExpired: true,
          profileExpired: true,
          storedRole: UserRole.patient,
        )();

        // Not home. The patient lookup reports "exists" when it fails, so a
        // deleted patient landed on a dashboard where every tile errored.
        expect(entry.destination, StartDestination.sessionExpired);
        expect(entry.notice, contains('sign in again'));
      },
    );

    test('a refused session outranks a stored role of none', () async {
      final entry = await _useCase(
        signedIn: true,
        doctorExpired: true,
        profileExpired: true,
      )();

      expect(entry.destination, StartDestination.sessionExpired);
    });

    test(
      'the server wording is carried through to the landing screen',
      () async {
        final entry = await _useCase(
          signedIn: true,
          doctorExpired: true,
          storedRole: UserRole.doctor,
        )();

        // The API writes user-facing copy on purpose, so it is shown as sent
        // rather than replaced with a second wording of the same thing.
        expect(entry.notice, _expiredSession.message);
      },
    );

    test('a 401 is not confused with an unreachable server', () async {
      // Same failed lookups, different cause: the network one keeps the
      // session, because a flaky connection says nothing about who the user is
      // and signing them out would cost a fresh code over a dropped packet.
      final expired = await _useCase(
        signedIn: true,
        doctorExpired: true,
        profileExpired: true,
        storedRole: UserRole.doctor,
      )();
      final offline = await _useCase(
        signedIn: true,
        doctorThrows: true,
        profileThrows: true,
        storedRole: UserRole.doctor,
      )();

      expect(expired.destination, StartDestination.sessionExpired);
      expect(offline.destination, StartDestination.landing);
    });
  });

  group('ResolveStartDestination · a registration left half-finished', () {
    // A verified number is not an account. Between the code being correct and
    // the form being saved there is a session with nothing behind it, and the
    // next launch used to reopen that form as if the user had never left.

    test('a cold launch does not reopen the patient details form', () async {
      final entry = await _useCase(
        signedIn: true,
        profileExists: false,
        storedRole: UserRole.patient,
      )();

      expect(entry.destination, StartDestination.registrationAbandoned);
      expect(
        entry.notice,
        isNotNull,
        reason: 'they are told why, not just moved',
      );
    });

    test('a cold launch does not reopen the certificate form', () async {
      final entry = await _useCase(
        signedIn: true,
        profileExists: false,
        storedRole: UserRole.doctor,
      )();

      expect(entry.destination, StartDestination.registrationAbandoned);
    });

    test('but straight after OTP those forms are exactly where to go', () async {
      // Same answer, opposite meaning: mid-flow it is the next step, and only a
      // relaunch turns it into evidence that the flow was abandoned.
      final useCase = _useCase(signedIn: true, profileExists: false);

      expect(
        (await useCase.forSignedInUser(role: UserRole.patient)).destination,
        StartDestination.completeProfile,
      );
      expect(
        (await useCase.forSignedInUser(role: UserRole.doctor)).destination,
        StartDestination.doctorSetup,
      );
    });

    test('a filed registration is resumed rather than abandoned', () async {
      // Waiting on review is an account, however incomplete the practice setup
      // that follows it.
      final pending = await _useCase(
        signedIn: true,
        profileExists: false,
        application: _application(DoctorApplicationStatus.underReview),
      )();

      expect(pending.destination, StartDestination.doctorPending);
    });

    test(
      'a rejected application is work to correct, not work abandoned',
      () async {
        // The destination is the same certificate form, but there is a filed
        // registration behind it — so the session survives and they land on the
        // form with their answers, rather than back at the number.
        final entry = await _useCase(
          signedIn: true,
          profileExists: false,
          application: _application(DoctorApplicationStatus.rejected),
        )();

        expect(entry.destination, StartDestination.doctorSetup);
      },
    );

    test('an unreachable server is not an abandoned registration', () async {
      // The session is deliberately kept on a failed lookup, and turning that
      // into a sign-out would make a flaky connection cost an OTP.
      final entry = await _useCase(
        signedIn: true,
        profileThrows: true,
        doctorThrows: true,
        storedRole: UserRole.doctor,
      )();

      expect(entry.destination, StartDestination.landing);
      expect(entry.notice, isNotNull);
    });
  });
}
