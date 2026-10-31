/// Named routes. Keep every path in one place so no screen hard-codes a
/// string literal.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/splash';
  static const String adminQueue = '/admin/approvals';
  static const String landing = '/';
  static const String phoneLogin = '/auth/phone';
  static const String otpVerification = '/auth/otp';
  static const String completeProfile = '/profile/complete';
  static const String patientProfile = '/profile';
  static const String editProfile = '/profile/edit';

  /// The patient's own account of their health — conditions, medication,
  /// allergies and past procedures.
  static const String medicalHistory = '/profile/medical-history';

  /// What the patient agrees to be contacted about.
  static const String patientSettings = '/profile/settings';

  /// Everything the app has told this user - booking confirmations and the
  /// reminder before a consultation starts.
  static const String notifications = '/notifications';

  /// The patient's consultation history.
  ///
  /// Reachable as a route as well as a nav-bar tab: the profile links to it,
  /// and a route that only exists as a tab cannot be linked to.
  static const String patientAppointments = '/appointments';

  /// The patient dashboard.
  static const String home = '/home';

  /// The doctor's dashboard.
  ///
  /// Its own route rather than `home` plus a `UserRole` argument. That argument
  /// decided which of two entirely different apps you were looking at, and
  /// every navigation that forgot it — a restart, the feedback screen, payment
  /// success, a `popUntil` — silently dropped a doctor into the patient
  /// dashboard. A route whose identity depends on an argument is a route that
  /// will be got wrong.
  static const String doctorHome = '/doctor/home';
  static const String consultOptions = '/consult';
  static const String doctorList = '/doctors';

  /// One doctor's profile, read before deciding to consult them.
  ///
  /// Its absence is what made tapping a doctor ring them: there was nowhere to
  /// look at somebody without calling them.
  static const String doctorDetail = '/doctors/detail';
  static const String scheduleConsultation = '/consult/schedule';
  static const String payment = '/payment';
  static const String paymentSuccess = '/payment/success';

  /// A booking that did not go through. Takes `PaymentFailedArgs` and pops a
  /// `PaymentFailureChoice`.
  static const String paymentFailed = '/payment/failed';
  static const String doctorMatching = '/consult/matching';
  static const String consultationFeedback = '/consult/feedback';
  static const String anonymousBooking = '/consult/anonymous';

  /// The patient–doctor chat that holds only their call recordings. Takes
  /// `RecordingsChatArgs`.
  static const String chat = '/chat';

  /// Every recorded consultation, by doctor (or by patient, for a doctor).
  static const String recordings = '/recordings';

  /// Plays one call recording. Takes `RecordingPlayerArgs`.
  static const String recordingPlayer = '/recordings/play';
  static const String call = '/call';

  /// The doctor's own profile and practice settings.
  static const String doctorProfile = '/doctor/profile';

  /// The fields a doctor may change themselves. Not the registration number,
  /// the degree or the specialty — those were reviewed, and a correction to one
  /// of them re-files the application.
  static const String doctorEditProfile = '/doctor/profile/edit';

  /// Where the doctor's fees are paid.
  static const String doctorBankAccount = '/doctor/payouts';

  /// The paperwork behind the registration, and what review made of it.
  static const String doctorCredentials = '/doctor/credentials';

  /// The doctor's own reviews, named — see `DoctorReview`.
  static const String doctorReviews = '/doctor/reviews';

  /// One of the doctor's own documents, as bytes. Takes a
  /// `DocumentViewerArgs`.
  static const String documentViewer = '/doctor/document';

  /// India's DPDP notice: what is collected, why, and how to withdraw.
  static const String dataProtection = '/legal/data-protection';

  static const String privacyPolicy = '/legal/privacy';

  static const String termsAndConditions = '/legal/terms';

  static const String cancellationAndRefund = '/legal/cancellation-refund';

  /// Support, and the named route for a data-protection grievance.
  static const String contactSupport = '/support';

  /// Erases the account. Play requires this to be reachable from inside the
  /// app, not only from a website.
  static const String deleteAccount = '/account/delete';

  /// The fee receipt for one consultation. Takes the `Appointment` itself —
  /// the history row already holds every field the receipt shows, so the
  /// screen opens with no fetch.
  static const String consultationReceipt = '/consultation/receipt';

  /// What the doctor agrees to be pinged about.
  static const String doctorSettings = '/doctor/settings';

  /// Who the doctor has consulted.
  static const String doctorPatients = '/doctor/patients';

  /// What the doctor has earned.
  static const String doctorEarnings = '/doctor/earnings';

  /// The doctor's consultation history.
  static const String doctorAppointments = '/doctor/appointments';

  // --- Doctor onboarding ----------------------------------------------------
  static const String doctorProfileSetup = '/doctor/setup';
  static const String doctorApplicationPending = '/doctor/pending';
  static const String doctorApplicationApproved = '/doctor/approved';
  static const String doctorPracticeSetup = '/doctor/practice';
  static const String doctorAvailability = '/doctor/availability';
}
