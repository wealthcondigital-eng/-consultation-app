import '../../../doctor_onboarding/domain/entities/doctor_application.dart';

/// Where the app should open, decided from the restored session.
enum StartDestination {
  /// No signed-in user: role selection, then login.
  landing,

  /// Signed in, but no patient row was ever written — onboarding was
  /// interrupted between verifying the phone number and saving the form.
  completeProfile,

  /// Signed in with a stored profile: straight to the patient dashboard.
  home,

  /// Signed in as an administrator: the review queue, not the patient app.
  adminQueue,

  /// A doctor who has not filed a registration yet, or whose last one was
  /// rejected and needs correcting.
  doctorSetup,

  /// A filed registration still waiting on a decision.
  doctorPending,

  /// A registration that was approved — the congratulations screen, then the
  /// practice wizard.
  doctorApproved,

  /// An approved doctor opening the app again: straight to their own
  /// dashboard.
  ///
  /// This was missing, and its absence is what made a doctor "turn back into a
  /// patient" on every restart. The enum could describe a doctor being set up
  /// but had nowhere to put one who already was, so the gate fell through to
  /// [home] — the patient dashboard.
  doctorHome,

  /// The stored session is no longer one the server recognises.
  ///
  /// Nothing local can detect this: the token is unexpired and well-formed, and
  /// the account behind it is gone — deleted, or on a database that has been
  /// reset. Only a request finds out, and the answer comes back 401.
  ///
  /// It gets its own destination rather than reusing a failed lookup, because
  /// the two need opposite handling and conflating them is what stranded
  /// people. A lookup that failed on a flaky network says nothing about who the
  /// user is, so the app keeps the session and lets the screen retry. A 401
  /// says the identity itself is void, and every screen past this point is one
  /// that cannot load: a doctor was walked into the certificate upload form, a
  /// patient onto a dashboard where every tile showed an error.
  ///
  /// The session is ended and [StartEntry.notice] is what the landing screen
  /// says.
  sessionExpired,

  /// The app was closed part-way through registration.
  ///
  /// A verified phone number is not an account. Between the code being correct
  /// and the form being saved there is a session with nothing behind it — no
  /// patient row, no filed application — and the next launch used to reopen
  /// that half-finished form as if the user had never left.
  ///
  /// Treated as abandoned rather than resumed, and only on a **cold launch**:
  /// finishing registration in one sitting is the whole point of the flow, and
  /// someone who walked away from it is more likely to be starting over than
  /// picking up a form they left yesterday. The session ends, so they come back
  /// through the number and the code — which is also the only way the app can
  /// be sure the person holding the phone is still the person who verified it.
  ///
  /// Note that a *filed* registration is not this: a doctor waiting on review,
  /// or one correcting a rejected application, has an account and resumes. Nor
  /// is someone with a usable profile on the other side — a patient who began
  /// registering as a doctor reopens on their patient dashboard instead.
  registrationAbandoned,
}

/// Where to open, and what that screen needs to know.
///
/// The application travels with the destination because the pending and
/// approved screens are built from it, and re-fetching it in the screen would
/// mean asking the backend the same question twice on one launch.
class StartEntry {
  const StartEntry(this.destination, {this.application, this.notice});

  final StartDestination destination;

  /// Set for the doctor destinations, null everywhere else.
  final DoctorApplication? application;

  /// Set for the destinations that end the session —
  /// [StartDestination.sessionExpired] and
  /// [StartDestination.registrationAbandoned] — and for an unconfirmed
  /// [StartDestination.landing]; null everywhere else. What the landing screen
  /// tells the user about why they are back at the start.
  final String? notice;

  /// Registration was started and never finished, so the session goes with it.
  ///
  /// Worded as the next step rather than as a failure: nothing went wrong, and
  /// what they have to do is exactly what they did the first time.
  factory StartEntry.abandonedRegistration() {
    return const StartEntry(
      StartDestination.registrationAbandoned,
      notice:
          'Your registration was not finished. '
          'Sign in again to start over.',
    );
  }

  /// The lookups could not answer — the network, not the session.
  ///
  /// Lands on the role choice with the session deliberately **kept**: a flaky
  /// connection is not a reason to make someone verify a phone number again,
  /// and the next launch with a working network restores them without an OTP.
  ///
  /// What it exists to avoid is the old fallback. An unconfirmed doctor was
  /// sent to the certificate form, which asks a registered doctor to re-upload
  /// paperwork they filed months ago, and an unconfirmed patient to a dashboard
  /// where every tile failed. Neither screen can recover, and neither offers a
  /// way back to the role choice.
  factory StartEntry.unconfirmed() {
    return const StartEntry(
      StartDestination.landing,
      notice:
          "We couldn't confirm your account. "
          'Check your connection, then continue below.',
    );
  }

  /// The server refused the stored session.
  ///
  /// [message] is the server's own wording where it sent some — the API writes
  /// "Please sign in again to continue." — and falls back to copy that says the
  /// same thing. Deliberately not phrased as an error the user caused: from
  /// their side nothing went wrong, they simply have to sign in again.
  factory StartEntry.expiredSession([String? message]) {
    return StartEntry(
      StartDestination.sessionExpired,
      notice: message == null || message.isEmpty
          ? 'Your session has ended. Please sign in again.'
          : message,
    );
  }
}
