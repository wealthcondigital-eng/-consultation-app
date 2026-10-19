import '../../../../core/error/failure.dart';
import '../../../../core/logging/auth_logger.dart';
import '../../../admin/domain/usecases/is_admin.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../doctor_onboarding/domain/entities/doctor_application.dart';
import '../../../doctor_onboarding/domain/entities/practice_setup.dart';
import '../../../onboarding/domain/entities/user_role.dart';
import '../../../onboarding/domain/usecases/get_selected_role.dart';
import '../../../doctor_onboarding/domain/repositories/doctor_onboarding_repository.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../entities/start_destination.dart';

/// Decides which screen the app opens on.
///
/// One place for the whole decision, used both on a cold launch and straight
/// after OTP, so the two can never disagree about where someone belongs.
///
/// The order matters. An administrator has no patient record and a doctor has
/// no patient record either — checking the patient table first would send both
/// of them into patient onboarding, which is exactly the bug this exists to
/// prevent.
///
/// **A number belongs to one journey.** Beyond routing, this is the gate that
/// keeps the two apps apart. A phone number registered as a doctor cannot be
/// used to enter the patient app and vice versa: the mismatch ends the session
/// and returns to the landing screen with an explanation, rather than quietly
/// starting a second account on the same identity. Two consequences worth
/// stating, because both were live bugs:
///
///  * A patient tapping **Doctor** on the landing screen no longer lands in
///    doctor registration, so the doctor app cannot be reached by choosing it.
///  * A doctor is never handed the patient dashboard, whatever they tapped.
///
/// And the doctor app itself is gated on the *review*, not on the tap: the only
/// route to [StartDestination.doctorHome] is an approved application, which
/// cannot exist without a medical certificate having been filed and accepted.
///
/// **Three answers, not two.** Every lookup below can say yes, no, or "I could
/// not tell", and the third is split again by why:
///
///  * a **401** means the account behind the token is gone, so the session ends
///    and the app returns to the role choice ([StartEntry.expiredSession]);
///  * any **other** failure is the network, which says nothing about who the
///    user is, so the session is kept ([StartEntry.unconfirmed]).
///
/// Collapsing those was what stranded people. An unconfirmed doctor used to be
/// sent to the certificate form and an unconfirmed patient to a dashboard that
/// could load nothing — both dead ends, on screens with no way back to the role
/// choice. Nobody is routed into either app now on an answer the app could not
/// actually get.
class ResolveStartDestination {
  const ResolveStartDestination(
    this._authRepository,
    this._profileRepository,
    this._doctorRepository,
    this._isAdmin,
    this._getSelectedRole,
  );

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final DoctorOnboardingRepository _doctorRepository;
  final IsAdmin _isAdmin;

  /// The journey this person chose, kept across launches.
  final GetSelectedRole _getSelectedRole;

  /// Cold launch: no session means the landing screen.
  ///
  /// The stored role is read and passed through. It used to launch with none,
  /// which is why a restart could put a doctor in the patient app: with nothing
  /// to say which journey they were in, an inconclusive lookup fell through to
  /// the patient branch.
  Future<StartEntry> call() async {
    if (!_authRepository.isSignedIn) {
      return const StartEntry(StartDestination.landing);
    }

    return _abandonedIfUnfinished(
      await forSignedInUser(role: await _storedRole()),
    );
  }

  /// Turns "resume the registration form" into "start over", on a cold launch
  /// only.
  ///
  /// The two destinations below are the ones reached with a verified phone
  /// number and nothing else stored against it — the patient details form and
  /// the certificate form on a first registration. Straight after OTP they are
  /// exactly right, which is why this wraps [call] and not [forSignedInUser]:
  /// the same answer means "carry on" in one context and "you left this
  /// half-done" in the other, and only the caller knows which.
  ///
  /// A doctor correcting a *rejected* application is deliberately not included.
  /// The destination is the same form, but there is a filed registration behind
  /// it and an account to go with it — that is work to resume, not work that
  /// was abandoned.
  StartEntry _abandonedIfUnfinished(StartEntry entry) {
    final unfinished = switch (entry.destination) {
      StartDestination.completeProfile => true,
      StartDestination.doctorSetup => entry.application == null,
      _ => false,
    };

    return unfinished ? StartEntry.abandonedRegistration() : entry;
  }

  Future<UserRole?> _storedRole() async {
    try {
      return await _getSelectedRole();
    } catch (_) {
      // Local storage being unavailable is no reason to fail a launch.
      return null;
    }
  }

  /// Straight after OTP, where being signed in is a given.
  ///
  /// [role] is what the person picked on the landing screen. It decides where a
  /// brand-new account with no records belongs — and, now, whether this account
  /// may be entered from this journey at all.
  Future<StartEntry> forSignedInUser({UserRole? role}) async {
    final entry = await _resolveFor(role);

    // Until this line the only trace of the decision was the screen the user
    // ended up on — no help at all when that screen is the one they started
    // from, which is what all three of the turn-back answers look like.
    AuthLogger.event('STARTUP · destination', {
      'chose role': role?.name ?? '(none)',
      'destination': entry.destination.name,
      'notice': entry.notice ?? '(none)',
    });

    return entry;
  }

  Future<StartEntry> _resolveFor(UserRole? role) async {
    if (await _isAdmin()) {
      return const StartEntry(StartDestination.adminQueue);
    }

    final doctor = await _doctorApplication();

    // The server refused the session itself, so no question below can be
    // answered and the identity the token names does not exist. Checked before
    // everything else: the alternative is routing on lookups that all failed
    // for the same reason, which is how a deleted account still ended up inside
    // one of the two apps.
    if (doctor.expired) return StartEntry.expiredSession(doctor.message);

    if (doctor.application case final application?) {
      // A registered doctor asking to come in as a patient. Refused rather than
      // silently routed to their own dashboard: a patient who taps Patient and
      // arrives in the doctor app has been told nothing about why, and this is
      // the first of the two directions that made the apps reachable from each
      // other.
      if (role == UserRole.patient) {
        return StartEntry.conflict(registeredAs: 'doctor');
      }

      return _forApplication(application);
    }

    // The doctor lookup failed rather than answering "no application", so
    // nothing below can be trusted to mean what it says.
    if (doctor.failed && role == UserRole.doctor) {
      // The role choice, not the certificate form. That form was the old
      // fallback because it re-reads the application and moves a doctor on —
      // but its first screen asks for a medical certificate, so a registered
      // doctor whose lookup merely timed out was told to upload paperwork they
      // had already filed, with no way back. The session is kept, so this costs
      // a tap rather than a re-verification.
      return StartEntry.unconfirmed();
    }
    // A patient is unaffected by a doctor lookup failing: their own record
    // below is the authority on where they go.

    final patient = await _patientProfile();

    if (patient.expired) return StartEntry.expiredSession(patient.message);

    if (role == UserRole.doctor) {
      // The other direction: a registered patient asking to come in as a
      // doctor. Refused for the same reason, and only when the lookup actually
      // answered — a failed read must not lock a real doctor out of their own
      // registration.
      if (patient.exists && !patient.failed) {
        return StartEntry.conflict(registeredAs: 'patient');
      }

      // Could not confirm they are not already a patient. The certificate form
      // is only the right screen for someone with no records at all, and this
      // is not knowably that person.
      if (patient.failed) return StartEntry.unconfirmed();

      // No records of any kind: a genuinely new doctor, who starts at the
      // certificate because that is where registration begins.
      return const StartEntry(StartDestination.doctorSetup);
    }

    // The patient dashboard carries its own retry, so a failed read is
    // survivable there in a way the certificate form never was — and the
    // session is already known to be good, because a 401 was handled above.
    if (patient.exists) return const StartEntry(StartDestination.home);

    return switch (role) {
      UserRole.patient => const StartEntry(StartDestination.completeProfile),
      // A restored session with no records of any kind: let them choose again
      // rather than guessing which app they meant to be in.
      UserRole.doctor || null => const StartEntry(StartDestination.landing),
    };
  }

  Future<StartEntry> _forApplication(DoctorApplication application) async {
    if (application.status == DoctorApplicationStatus.approved) {
      return _forApprovedDoctor(application);
    }

    return switch (application.status) {
      // Waiting. Shown on every launch until a reviewer decides, which is the
      // point: a doctor under review has no business in the patient app.
      DoctorApplicationStatus.underReview => StartEntry(
        StartDestination.doctorPending,
        application: application,
      ),
      // Handled above, where the practice setup decides between the two.
      DoctorApplicationStatus.approved => StartEntry(
        StartDestination.doctorHome,
        application: application,
      ),
      // Rejected sends them back to the form to correct it. A draft has no
      // accepted certificate behind it, so it goes to the same place — the
      // doctor app is not reachable until a reviewer has seen the paperwork.
      DoctorApplicationStatus.rejected || DoctorApplicationStatus.draft =>
        StartEntry(StartDestination.doctorSetup, application: application),
    };
  }

  /// An approved doctor goes to their dashboard — unless they have no fees yet,
  /// in which case they are shown the approval screen that sets them up.
  ///
  /// Approval alone is not a working practice. A doctor with no consultation
  /// fee cannot be booked by anybody, so sending them to a dashboard is sending
  /// them somewhere nothing can happen; the approval screen is the one that
  /// leads to fees and then availability.
  ///
  /// Gated on the fees rather than on "have we shown this before", which is
  /// what makes it safe to show again. The version of this that sent every
  /// approved doctor here made a working practice re-run the wizard to get
  /// anywhere; keyed to whether the setup is actually missing, it stops asking
  /// the moment it has been done, and keeps asking while there is a real reason
  /// to.
  Future<StartEntry> _forApprovedDoctor(DoctorApplication application) async {
    final PracticeSetup setup;
    try {
      setup = await _doctorRepository.fetchPracticeSetup();
    } catch (error) {
      // The dashboard carries its own retry, and a doctor who *has* set their
      // fees must never be pushed back through the wizard because one read
      // failed.
      _logLookupFailure('practice setup', error);
      return StartEntry(StartDestination.doctorHome, application: application);
    }

    final canBeBooked = setup.videoFee != null || setup.audioFee != null;

    return StartEntry(
      canBeBooked
          ? StartDestination.doctorHome
          : StartDestination.doctorApproved,
      application: application,
    );
  }

  /// Never throws: a lookup that fails must not strand someone on an error
  /// screen at launch. But whether it failed is **not** the same answer as
  /// "there is no application", and collapsing the two is what sent doctors to
  /// the wrong app — so the difference is carried out of here, along with
  /// whether the cause was a refused session or an unreachable server.
  Future<_DoctorLookup> _doctorApplication() async {
    try {
      return _DoctorLookup(await _doctorRepository.fetchMyApplication());
    } on Failure catch (failure) {
      if (failure.isNotFound) {
        return const _DoctorLookup(null, failed: false);
      }
      _logLookupFailure('doctor application', failure);
      return _DoctorLookup(
        null,
        failed: true,
        expired: failure.isSessionExpired,
        message: failure.message,
      );
    } catch (error) {
      _logLookupFailure('doctor application', error);
      return const _DoctorLookup(null, failed: true);
    }
  }

  /// What the server actually said, for the one case where the app turns the
  /// user back at the door. A failed lookup is swallowed on purpose — it must
  /// not strand anyone on an error screen — but swallowing it silently is what
  /// made "it just returns me to the start" impossible to explain.
  static void _logLookupFailure(String lookup, Object error) {
    AuthLogger.event('STARTUP · lookup failed', {
      'lookup': lookup,
      'code': error is Failure ? error.code ?? '(none)' : error.runtimeType,
      'message': error is Failure ? error.message : error.toString(),
      'read as': switch (error) {
        final Failure f when f.isSessionExpired => 'session expired → sign out',
        final Failure f when f.isNotFound => 'no record',
        _ => 'could not confirm',
      },
    });
  }

  /// The same answers for the patient record.
  ///
  /// It used to be a plain bool that returned true on failure, so the app could
  /// not tell "this is a patient" from "the network is down" — harmless while
  /// the only consequence was which dashboard opened, and not harmless now that
  /// the same answer decides whether a doctor is turned away.
  Future<_PatientLookup> _patientProfile() async {
    try {
      return _PatientLookup(exists: await _profileRepository.hasProfile());
    } on Failure catch (failure) {
      if (failure.isNotFound) {
        return const _PatientLookup(exists: false, failed: false);
      }
      _logLookupFailure('patient profile', failure);
      // Still `exists: true` for a plain network failure — the session is fine,
      // so a patient keeps their dashboard and it surfaces its own retry. A
      // refused session is the opposite case and is carried out separately.
      return _PatientLookup(
        exists: true,
        failed: true,
        expired: failure.isSessionExpired,
        message: failure.message,
      );
    } catch (error) {
      _logLookupFailure('patient profile', error);
      return const _PatientLookup(exists: true, failed: true);
    }
  }
}

/// A doctor lookup that can say "no application", "I could not tell", and "the
/// session itself was refused" separately.
class _DoctorLookup {
  const _DoctorLookup(
    this.application, {
    this.failed = false,
    this.expired = false,
    this.message,
  });

  final DoctorApplication? application;
  final bool failed;

  /// The server answered 401: this session is over.
  final bool expired;

  /// The server's own wording, shown on the landing screen when [expired].
  final String? message;
}

/// The same answers for the patient record.
class _PatientLookup {
  const _PatientLookup({
    required this.exists,
    this.failed = false,
    this.expired = false,
    this.message,
  });

  final bool exists;
  final bool failed;
  final bool expired;
  final String? message;
}
