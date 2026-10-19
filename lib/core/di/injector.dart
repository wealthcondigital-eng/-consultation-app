import 'package:flutter/foundation.dart';
import '../../features/admin/data/datasources/admin_remote_data_source.dart';
import '../../features/admin/data/datasources/api_admin_remote_data_source.dart';
import '../../features/admin/data/repositories/admin_repository_impl.dart';
import '../../features/admin/domain/repositories/admin_repository.dart';
import '../../features/admin/domain/usecases/decide_doctor_application.dart';
import '../../features/admin/domain/usecases/get_pending_doctors.dart';
import '../../features/admin/domain/usecases/is_admin.dart';
import '../../features/admin/presentation/controllers/admin_queue_controller.dart';
import '../../features/appointments/data/datasources/appointment_remote_data_source.dart';
import '../../features/appointments/data/repositories/appointment_repository_impl.dart';
import '../../features/appointments/domain/repositories/appointment_repository.dart';
import '../../features/appointments/domain/usecases/get_appointments.dart';
import '../../features/anonymous/data/datasources/anonymous_consult_remote_data_source.dart';
import '../../features/anonymous/data/repositories/anonymous_consult_repository_impl.dart';
import '../../features/anonymous/domain/repositories/anonymous_consult_repository.dart';
import '../../features/anonymous/domain/usecases/suggest_code_name.dart';
import '../../features/anonymous/presentation/controllers/anonymous_booking_controller.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/otp_auth_remote_data_source.dart';
import '../../features/chat/data/datasources/chat_remote_data_source.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/usecases/open_chat_thread.dart';
import '../../features/chat/domain/usecases/send_chat_message.dart';
import '../../features/chat/presentation/controllers/chat_controller.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/request_otp.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/verify_otp.dart';
import '../../features/auth/presentation/controllers/otp_verification_controller.dart';
import '../../features/auth/presentation/controllers/phone_login_controller.dart';
import '../../features/call/data/datasources/call_signalling_client.dart';
import '../../features/call/data/datasources/webrtc_media_service.dart';
import '../../features/call/data/repositories/call_repository_impl.dart';
import '../../features/call/domain/repositories/call_repository.dart';
import '../../features/call/presentation/controllers/active_call.dart';
import '../../features/call/presentation/controllers/call_controller.dart';
import '../../features/consultation/data/datasources/consultation_remote_data_source.dart';
import '../../features/consultation/data/repositories/consultation_repository_impl.dart';
import '../../features/consultation/domain/repositories/consultation_repository.dart';
import '../../features/consultation/data/datasources/api_matchmaking_remote_data_source.dart';
import '../../features/consultation/data/datasources/consultation_session_remote_data_source.dart';
import '../../features/consultation/data/repositories/consultation_session_repository_impl.dart';
import '../../features/consultation/domain/repositories/consultation_session_repository.dart';
import '../../features/consultation/domain/usecases/answer_consultations.dart';
import '../../features/consultation/domain/usecases/start_instant_consultation.dart';
import '../../features/consultation/presentation/controllers/incoming_consultation_controller.dart';
import '../../features/consultation/data/datasources/matchmaking_remote_data_source.dart';
import '../../features/consultation/data/repositories/matchmaking_repository_impl.dart';
import '../../features/consultation/domain/repositories/matchmaking_repository.dart';
import '../../features/consultation/domain/usecases/find_doctor.dart';
import '../../features/consultation/domain/usecases/get_consult_options.dart';
import '../../features/consultation/presentation/controllers/consultation_feedback_controller.dart';
import '../../features/consultation/presentation/controllers/doctor_matching_controller.dart';
import '../../features/consultation/presentation/controllers/doctor_search_session.dart';
import '../../features/consultation/presentation/controllers/consult_options_controller.dart';
import '../../features/doctor_onboarding/data/datasources/certificate_picker.dart';
import '../../features/doctor_onboarding/data/datasources/doctor_onboarding_remote_data_source.dart';
import '../../features/doctor_onboarding/data/datasources/api_doctor_onboarding_remote_data_source.dart';
import '../../features/doctor_onboarding/data/repositories/doctor_onboarding_repository_impl.dart';
import '../../features/doctor_onboarding/domain/repositories/doctor_onboarding_repository.dart';
import '../../features/doctor_onboarding/domain/usecases/get_doctor_setup_options.dart';
import '../../features/doctor_onboarding/domain/usecases/manage_availability.dart';
import '../../features/doctor_onboarding/domain/usecases/manage_practice_setup.dart';
import '../../features/doctor_onboarding/domain/usecases/parse_medical_certificate.dart';
import '../../features/doctor_onboarding/domain/usecases/submit_doctor_application.dart';
import '../../features/doctor_onboarding/domain/usecases/watch_application_status.dart';
import '../../features/doctor_onboarding/presentation/controllers/application_status_controller.dart';
import '../../features/doctor_onboarding/presentation/controllers/availability_controller.dart';
import '../../features/doctor_onboarding/presentation/controllers/doctor_setup_controller.dart';
import '../../features/doctor_onboarding/presentation/controllers/practice_setup_controller.dart';
import '../../features/doctor_practice/data/datasources/doctor_practice_remote_data_source.dart';
import '../../features/doctor_practice/data/datasources/fake_doctor_practice_remote_data_source.dart';
import '../../features/doctor_practice/data/repositories/doctor_practice_repository_impl.dart';
import '../../features/doctor_practice/domain/repositories/doctor_practice_repository.dart';
import '../../features/doctor_practice/domain/usecases/manage_doctor_practice.dart';
import '../../features/doctor_practice/presentation/controllers/bank_account_controller.dart';
import '../../features/doctor_practice/presentation/controllers/doctor_credentials_controller.dart';
import '../../features/doctor_practice/presentation/controllers/doctor_earnings_controller.dart';
import '../../features/doctor_practice/presentation/controllers/doctor_patients_controller.dart';
import '../../features/doctor_practice/presentation/controllers/doctor_reviews_controller.dart';
import '../../features/doctor_practice/presentation/controllers/doctor_profile_edit_controller.dart';
import '../../features/doctor_practice/presentation/controllers/doctor_settings_controller.dart';
import '../../features/doctor_profile/presentation/controllers/doctor_profile_controller.dart';
import '../../features/doctors/data/datasources/api_doctor_remote_data_source.dart';
import '../../features/doctors/data/datasources/doctor_remote_data_source.dart';
import '../../features/doctors/data/repositories/doctor_repository_impl.dart';
import '../../features/doctors/domain/repositories/doctor_repository.dart';
import '../../features/doctors/domain/usecases/get_doctor_profile.dart';
import '../../features/doctors/domain/usecases/get_doctors.dart';
import '../../features/doctors/presentation/controllers/doctor_list_controller.dart';
import '../../features/home/data/datasources/api_home_remote_data_source.dart';
import '../../features/home/data/datasources/home_remote_data_source.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/domain/usecases/get_home_feed.dart';
import '../../features/home/domain/usecases/get_patient_dashboard.dart';
import '../../features/home/domain/usecases/manage_doctor_dashboard.dart';
import '../../features/home/presentation/controllers/doctor_home_controller.dart';
import '../../features/home/presentation/controllers/ring_readiness_controller.dart';
import '../../features/home/presentation/controllers/patient_home_controller.dart';
import '../../features/onboarding/data/datasources/role_local_data_source.dart';
import '../../features/onboarding/data/repositories/role_repository_impl.dart';
import '../../features/onboarding/domain/repositories/role_repository.dart';
import '../../features/onboarding/domain/usecases/get_selected_role.dart';
import '../../features/onboarding/domain/usecases/select_role.dart';
import '../../features/onboarding/presentation/controllers/landing_controller.dart';
import '../../features/payment/data/datasources/api_payment_remote_data_source.dart';
import '../../features/payment/data/datasources/payment_gateway.dart';
import '../../features/payment/data/datasources/payment_link_gateway.dart';
import '../../features/payment/data/datasources/payment_remote_data_source.dart';
import '../../features/payment/data/datasources/razorpay_payment_gateway.dart';
import '../../features/payment/data/repositories/payment_repository_impl.dart';
import '../../features/payment/domain/repositories/payment_repository.dart';
import '../../features/payment/domain/usecases/get_payment_summary.dart';
import '../../features/payment/domain/usecases/pay_for_consultation.dart';
import '../../features/payment/domain/usecases/verify_upi_id.dart';
import '../../features/payment/presentation/controllers/payment_controller.dart';
import '../../features/scheduling/data/datasources/api_schedule_remote_data_source.dart';
import '../../features/scheduling/data/datasources/resilient_schedule_remote_data_source.dart';
import '../../features/scheduling/data/datasources/schedule_remote_data_source.dart';
import '../../features/scheduling/data/repositories/schedule_repository_impl.dart';
import '../../features/scheduling/domain/repositories/schedule_repository.dart';
import '../../features/scheduling/domain/usecases/get_doctor_schedule.dart';
import '../../features/scheduling/presentation/controllers/schedule_consultation_controller.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../features/profile/data/datasources/api_profile_remote_data_source.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/get_patient_account.dart';
import '../../features/profile/domain/usecases/manage_medical_history.dart';
import '../../features/profile/domain/usecases/delete_patient_account.dart';
import '../../features/profile/domain/usecases/manage_medical_reports.dart';
import '../../features/profile/presentation/controllers/medical_reports_controller.dart';
import '../media/medical_report_picker.dart';
import '../../features/profile/domain/usecases/manage_patient_settings.dart';
import '../../features/profile/domain/usecases/manage_profile_photo.dart';
import '../../features/profile/domain/usecases/has_patient_profile.dart';
import '../../features/profile/domain/usecases/save_patient_profile.dart';
import '../../features/profile/domain/usecases/update_patient_details.dart';
import '../../features/profile/presentation/controllers/edit_profile_controller.dart';
import '../../features/profile/presentation/controllers/complete_profile_controller.dart';
import '../../features/profile/presentation/controllers/medical_history_controller.dart';
import '../../features/profile/presentation/controllers/patient_profile_controller.dart';
import '../../features/profile/presentation/controllers/patient_settings_controller.dart';
import '../../features/startup/domain/usecases/resolve_start_destination.dart';
import '../media/profile_photo_picker.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/connectivity_monitor.dart';
import '../l10n/language_controller.dart';
import '../theme/theme_controller.dart';
import '../update/app_update_controller.dart';
import '../push/call_kit_bridge.dart';
import '../push/push_service.dart';
import '../push/ring_readiness_probe.dart';
import '../../features/notifications/data/datasources/api_notification_remote_data_source.dart';
import '../../features/notifications/data/datasources/notification_remote_data_source.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notifications/domain/usecases/announce_appointments.dart';
import '../../features/notifications/domain/usecases/announce_booking.dart';
import '../../features/notifications/domain/usecases/get_notifications.dart';
import '../../features/notifications/domain/usecases/mark_notifications_read.dart';
import '../../features/notifications/presentation/controllers/notifications_controller.dart';
import '../session/auth_session.dart';
import '../session/session_expiry.dart';
import '../session/session_store.dart';
import 'service_locator.dart';

/// Which data sources the object graph is built from.
enum AppBackend {
  /// In-memory stubs. The default, so the widget tests need neither a running
  /// API nor a network connection.
  fake,

  /// The consultation API in `server/` — phone OTP over SMS India Hub, and
  /// every record in MongoDB. `main()` opts into this explicitly.
  ///
  /// One backend, not two. Identity, patients, doctors and the review queue all
  /// reach the same service over the same bearer token; there is no second
  /// database with its own authorisation model to keep in step.
  live,
}

/// Wires the object graph. Called once from `main()` before `runApp`.
///
/// Registration order follows the dependency direction: data sources, then
/// repositories, then use cases, then controllers.
void configureDependencies({AppBackend backend = AppBackend.fake}) {
  // The OTP resend cooldowns are keyed by phone number and held statically, so
  // they outlive the controller that set them — which is the point: the server
  // throttles the number, and a new controller must not hand out a request the
  // gateway is going to refuse. They are cleared here because a rebuilt object
  // graph is a fresh process in every case that matters: `main()` calls this
  // once, and a test calls it per case and must not inherit the window set by
  // whichever test ran before it.
  PhoneLoginController.resetCooldowns();

  sl
    // --- Onboarding: data ---------------------------------------------------
    ..registerLazySingleton<RoleLocalDataSource>(
      () => switch (backend) {
        AppBackend.fake => InMemoryRoleLocalDataSource(),
        // Has to outlive the process: the role decides which of two dashboards
        // the app opens on, and holding it in memory meant every restart
        // forgot, dropping doctors into the patient app.
        AppBackend.live => const PreferencesRoleLocalDataSource(),
      },
    )
    ..registerLazySingleton<RoleRepository>(
      () => RoleRepositoryImpl(sl<RoleLocalDataSource>()),
    )
    // --- Onboarding: domain -------------------------------------------------
    ..registerLazySingleton<SelectRole>(() => SelectRole(sl<RoleRepository>()))
    ..registerLazySingleton<GetSelectedRole>(
      () => GetSelectedRole(sl<RoleRepository>()),
    )
    // --- Onboarding: presentation -------------------------------------------
    // A factory: each landing screen gets its own controller instance.
    ..registerFactory<LandingController>(
      () => LandingController(sl<SelectRole>()),
    )
    // --- Session ------------------------------------------------------------
    // Registered ahead of everything that reads identity. `main()` awaits
    // `restore()` on this before the first frame, which is what makes
    // `AuthSession.isSignedIn` — and therefore startup routing — synchronous.
    ..registerLazySingleton<SessionStore>(
      () => switch (backend) {
        AppBackend.fake => InMemorySessionStore(),
        AppBackend.live => const PreferencesSessionStore(),
      },
    )
    ..registerLazySingleton<AuthSession>(
      () => AuthSession(sl<SessionStore>(), sl<SessionExpiry>()),
    )
    // One instance for the whole app: the client raises on it and the widget
    // above the navigator listens to it. Two would mean a rejected session
    // nobody heard about.
    ..registerLazySingleton<SessionExpiry>(SessionExpiry.new)
    // Also one instance: the client reports what it learns from every request
    // and the widget above the navigator shows the offline screen from it.
    ..registerLazySingleton<ConnectivityMonitor>(ConnectivityMonitor.new)
    // Light, dark or system. One instance: it owns the active palette.
    ..registerLazySingleton<ThemeController>(ThemeController.new)
    // English or Hindi. One instance: it owns the active string table.
    ..registerLazySingleton<LanguageController>(LanguageController.new)
    // Google Play in-app updates. One instance, so the banner on either home
    // screen shows the same download.
    ..registerLazySingleton<AppUpdateController>(AppUpdateController.new)
    // Registered against the signed-in user, so it is created lazily and used
    // from the OTP screen once there is a user to file it against.
    ..registerLazySingleton<PushService>(() => PushService(sl<ApiClient>()))
    // One instance: it holds the Accept tapped on the phone's ringing screen
    // until the doctor's home is there to open the call.
    ..registerLazySingleton<CallKitBridge>(() => CallKitBridge(sl<ApiClient>()))
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(
        sl<AuthSession>(),
        sl<SessionExpiry>(),
        sl<ConnectivityMonitor>(),
      ),
    )
    // The camera and the gallery, behind an interface — a widget test has
    // neither, and a screen calling the plugin directly is a screen no test
    // can drive. Registered here rather than under one feature, because both
    // roles have a photo.
    ..registerLazySingleton<ProfilePhotoPicker>(
      () => switch (backend) {
        AppBackend.fake => const FakeProfilePhotoPicker(),
        AppBackend.live => const PlatformProfilePhotoPicker(),
      },
    )
    // --- Auth: data ---------------------------------------------------------
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => switch (backend) {
        AppBackend.fake => FakeAuthRemoteDataSource(sl<AuthSession>()),
        AppBackend.live => OtpAuthRemoteDataSource(
          sl<ApiClient>(),
          sl<AuthSession>(),
        ),
      },
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(sl<AuthRemoteDataSource>()),
    )
    // --- Auth: domain -------------------------------------------------------
    ..registerLazySingleton<RequestOtp>(() => RequestOtp(sl<AuthRepository>()))
    ..registerLazySingleton<VerifyOtp>(() => VerifyOtp(sl<AuthRepository>()))
    ..registerLazySingleton<SignOut>(() => SignOut(sl<AuthRepository>()))
    // --- Auth: presentation -------------------------------------------------
    ..registerFactory<PhoneLoginController>(
      () => PhoneLoginController(sl<RequestOtp>()),
    )
    ..registerFactory<OtpVerificationController>(
      () => OtpVerificationController(
        sl<VerifyOtp>(),
        sl<RequestOtp>(),
        sl<ResolveStartDestination>(),
        // Undoes a sign-in that reached the wrong journey — a number already
        // registered under the other role. The code was right, so a session is
        // open; leaving it open would put them one restart away from the app
        // they were just turned away from.
        sl<SignOut>(),
      ),
    )
    // --- Profile: data ------------------------------------------------------
    ..registerLazySingleton<ProfileRemoteDataSource>(
      () => switch (backend) {
        // Not const: the stub holds the medical record and the photo for the
        // run, so saving one and reading it back agrees.
        AppBackend.fake => FakeProfileRemoteDataSource(),
        AppBackend.live => ApiProfileRemoteDataSource(sl<ApiClient>()),
      },
    )
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(sl<ProfileRemoteDataSource>()),
    )
    // --- Profile: domain ----------------------------------------------------
    ..registerLazySingleton<SavePatientProfile>(
      () => SavePatientProfile(sl<ProfileRepository>()),
    )
    ..registerLazySingleton<GetPatientAccount>(
      () => GetPatientAccount(sl<ProfileRepository>()),
    )
    ..registerLazySingleton<UpdatePatientDetails>(
      () => UpdatePatientDetails(sl<ProfileRepository>()),
    )
    ..registerFactory<EditProfileController>(
      () => EditProfileController(sl<UpdatePatientDetails>()),
    )
    ..registerLazySingleton<HasPatientProfile>(
      () => HasPatientProfile(sl<ProfileRepository>()),
    )
    ..registerLazySingleton<ManageMedicalHistory>(
      () => ManageMedicalHistory(sl<ProfileRepository>()),
    )
    ..registerLazySingleton<MedicalReportPicker>(
      PlatformMedicalReportPicker.new,
    )
    ..registerLazySingleton<ManageMedicalReports>(
      () => ManageMedicalReports(sl<ProfileRepository>()),
    )
    // A factory, not a singleton: the section disposes its controller when the
    // medical record closes, and a singleton would be dead the second time the
    // screen opened.
    ..registerFactory<MedicalReportsController>(
      () => MedicalReportsController(sl<ManageMedicalReports>()),
    )
    ..registerLazySingleton<DeletePatientAccount>(
      () => DeletePatientAccount(sl<ProfileRepository>()),
    )
    ..registerLazySingleton<ManagePatientSettings>(
      () => ManagePatientSettings(sl<ProfileRepository>()),
    )
    ..registerLazySingleton<ManageProfilePhoto>(
      () => ManageProfilePhoto(sl<ProfileRepository>()),
    )
    // --- Profile: presentation ----------------------------------------------
    ..registerFactory<CompleteProfileController>(
      () => CompleteProfileController(sl<SavePatientProfile>()),
    )
    ..registerFactory<PatientProfileController>(
      () => PatientProfileController(
        sl<GetPatientAccount>(),
        sl<SignOut>(),
        sl<ManageProfilePhoto>(),
        sl<ProfilePhotoPicker>(),
        // The running totals, which moved off the dashboard and onto the
        // profile — a record belongs where records are kept.
        sl<GetPatientDashboard>(),
      ),
    )
    ..registerFactory<MedicalHistoryController>(
      () => MedicalHistoryController(sl<ManageMedicalHistory>()),
    )
    ..registerFactory<PatientSettingsController>(
      () => PatientSettingsController(sl<ManagePatientSettings>()),
    )
    // --- Admin --------------------------------------------------------------
    ..registerLazySingleton<AdminRemoteDataSource>(
      () => switch (backend) {
        AppBackend.fake => FakeAdminRemoteDataSource(),
        AppBackend.live => ApiAdminRemoteDataSource(sl<ApiClient>()),
      },
    )
    ..registerLazySingleton<AdminRepository>(
      () => AdminRepositoryImpl(sl<AdminRemoteDataSource>()),
    )
    ..registerLazySingleton<IsAdmin>(() => IsAdmin(sl<AdminRepository>()))
    ..registerLazySingleton<GetPendingDoctors>(
      () => GetPendingDoctors(sl<AdminRepository>()),
    )
    ..registerLazySingleton<DecideDoctorApplication>(
      () => DecideDoctorApplication(sl<AdminRepository>()),
    )
    ..registerFactory<AdminQueueController>(
      () => AdminQueueController(
        sl<GetPendingDoctors>(),
        sl<DecideDoctorApplication>(),
        sl<AdminRepository>(),
      ),
    )
    // --- Startup ------------------------------------------------------------
    ..registerLazySingleton<ResolveStartDestination>(
      () => ResolveStartDestination(
        sl<AuthRepository>(),
        sl<ProfileRepository>(),
        sl<DoctorOnboardingRepository>(),
        sl<IsAdmin>(),
        sl<GetSelectedRole>(),
      ),
    )
    // --- Home: data ---------------------------------------------------------
    ..registerLazySingleton<HomeRemoteDataSource>(
      () => switch (backend) {
        AppBackend.fake => FakeHomeRemoteDataSource(),
        AppBackend.live => ApiHomeRemoteDataSource(sl<ApiClient>()),
      },
    )
    ..registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(sl<HomeRemoteDataSource>()),
    )
    // --- Home: domain -------------------------------------------------------
    ..registerLazySingleton<GetHomeFeed>(
      () => GetHomeFeed(sl<HomeRepository>()),
    )
    ..registerLazySingleton<GetPatientDashboard>(
      () => GetPatientDashboard(sl<HomeRepository>()),
    )
    ..registerLazySingleton<ManageDoctorDashboard>(
      () => ManageDoctorDashboard(sl<HomeRepository>()),
    )
    // --- Home: presentation -------------------------------------------------
    ..registerFactory<PatientHomeController>(
      () => PatientHomeController(
        sl<GetHomeFeed>(),
        // The greeting, the figures and the live consultation all come from
        // the patient's own dashboard rather than from the catalogue feed.
        sl<GetPatientDashboard>(),
      ),
    )
    ..registerFactory<DoctorHomeController>(
      () => DoctorHomeController(sl<ManageDoctorDashboard>()),
    )
    // The phone's own settings on the live build. The stand-in reports a phone
    // that allows everything, so no test has to be about ringing to pass.
    ..registerLazySingleton<RingReadinessProbe>(
      () => switch (backend) {
        AppBackend.fake => const ReadyRingReadinessProbe(),
        AppBackend.live => const PlatformRingReadinessProbe(),
      },
    )
    ..registerFactory<RingReadinessController>(
      () => RingReadinessController(sl<RingReadinessProbe>()),
    )
    // --- Consultation: data -------------------------------------------------
    ..registerLazySingleton<ConsultationRemoteDataSource>(
      FakeConsultationRemoteDataSource.new,
    )
    ..registerLazySingleton<ConsultationRepository>(
      () => ConsultationRepositoryImpl(sl<ConsultationRemoteDataSource>()),
    )
    // --- Consultation: domain -----------------------------------------------
    ..registerLazySingleton<GetConsultOptions>(
      () => GetConsultOptions(sl<ConsultationRepository>()),
    )
    // --- Consultation: presentation -----------------------------------------
    ..registerFactory<ConsultOptionsController>(
      () => ConsultOptionsController(sl<GetConsultOptions>()),
    )
    // --- Instant consultation: data -----------------------------------------
    // The broker that puts a patient and a doctor in the same room. Both sides
    // of the call read from it: the patient's matching screen and the doctor's
    // incoming-call watcher are two views of one record.
    ..registerLazySingleton<ConsultationSessionRemoteDataSource>(
      () => switch (backend) {
        AppBackend.fake => const FakeConsultationSessionRemoteDataSource(),
        AppBackend.live => ApiConsultationSessionRemoteDataSource(
          sl<ApiClient>(),
        ),
      },
    )
    ..registerLazySingleton<ConsultationSessionRepository>(
      () => ConsultationSessionRepositoryImpl(
        sl<ConsultationSessionRemoteDataSource>(),
      ),
    )
    // --- Instant consultation: domain ---------------------------------------
    ..registerLazySingleton<StartInstantConsultation>(
      () => StartInstantConsultation(sl<ConsultationSessionRepository>()),
    )
    ..registerLazySingleton<AnswerConsultations>(
      () => AnswerConsultations(sl<ConsultationSessionRepository>()),
    )
    ..registerLazySingleton<ManageConsultationCall>(
      () => ManageConsultationCall(sl<ConsultationSessionRepository>()),
    )
    // --- Instant consultation: presentation ---------------------------------
    ..registerFactory<IncomingConsultationController>(
      () => IncomingConsultationController(sl<AnswerConsultations>()),
    )
    // --- Matchmaking --------------------------------------------------------
    ..registerLazySingleton<MatchmakingRemoteDataSource>(
      () => switch (backend) {
        AppBackend.fake => const FakeMatchmakingRemoteDataSource(),
        // Backed by the consultation broker rather than a second endpoint: the
        // three steps the patient watches are the states of the record their
        // request created.
        AppBackend.live => ApiMatchmakingRemoteDataSource(
          sl<ConsultationSessionRemoteDataSource>(),
        ),
      },
    )
    ..registerLazySingleton<MatchmakingRepository>(
      () => MatchmakingRepositoryImpl(sl<MatchmakingRemoteDataSource>()),
    )
    ..registerLazySingleton<FindDoctor>(
      () => FindDoctor(sl<MatchmakingRepository>()),
    )
    ..registerFactory<ConsultationFeedbackController>(
      () => ConsultationFeedbackController(sl<ManageConsultationCall>()),
    )
    ..registerFactory<DoctorMatchingController>(
      () => DoctorMatchingController(sl<FindDoctor>()),
    )
    // A lazy **singleton**, and that is the whole point of it: a search for a
    // doctor now outlives the screen that started it, so the dashboard can
    // report one the patient backed out of. Two instances would be two
    // searches and a dashboard showing whichever it happened to hold.
    ..registerLazySingleton<DoctorSearchSession>(
      () => DoctorSearchSession(sl<GetDoctors>(), sl<FindDoctor>()),
    )
    // --- Anonymous consult: data --------------------------------------------
    ..registerLazySingleton<AnonymousConsultRemoteDataSource>(
      // Local on both backends: the alias list is reference data the app owns,
      // like the speciality glyphs. The consultation itself is filed through
      // the session data source with `isAnonymous` set, which is where it
      // always belonged 2014 there is no anonymous endpoint to switch on.
      LocalAnonymousConsultRemoteDataSource.new,
    )
    ..registerLazySingleton<AnonymousConsultRepository>(
      () => AnonymousConsultRepositoryImpl(
        sl<AnonymousConsultRemoteDataSource>(),
      ),
    )
    // --- Anonymous consult: domain ------------------------------------------
    ..registerLazySingleton<SuggestCodeName>(
      () => SuggestCodeName(sl<AnonymousConsultRepository>()),
    )
    // --- Anonymous consult: presentation ------------------------------------
    ..registerFactory<AnonymousBookingController>(
      AnonymousBookingController.new,
    )
    // --- Chat: data ---------------------------------------------------------
    ..registerLazySingleton<ChatRemoteDataSource>(FakeChatRemoteDataSource.new)
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(sl<ChatRemoteDataSource>()),
    )
    // --- Chat: domain -------------------------------------------------------
    ..registerLazySingleton<OpenChatThread>(
      () => OpenChatThread(sl<ChatRepository>()),
    )
    ..registerLazySingleton<SendChatMessage>(
      () => SendChatMessage(sl<ChatRepository>()),
    )
    // --- Chat: presentation -------------------------------------------------
    ..registerFactory<ChatController>(
      () => ChatController(sl<OpenChatThread>(), sl<SendChatMessage>()),
    )
    // --- Doctor onboarding: data --------------------------------------------
    ..registerLazySingleton<CertificatePicker>(
      () => switch (backend) {
        AppBackend.fake => const FakeCertificatePicker(),
        AppBackend.live => const PlatformCertificatePicker(),
      },
    )
    ..registerLazySingleton<DoctorOnboardingRemoteDataSource>(
      () => switch (backend) {
        AppBackend.fake => FakeDoctorOnboardingRemoteDataSource(),
        AppBackend.live => ApiDoctorOnboardingRemoteDataSource(sl<ApiClient>()),
      },
    )
    ..registerLazySingleton<DoctorOnboardingRepository>(
      () => DoctorOnboardingRepositoryImpl(
        sl<DoctorOnboardingRemoteDataSource>(),
      ),
    )
    // --- Doctor onboarding: domain ------------------------------------------
    ..registerLazySingleton<GetDoctorSetupOptions>(
      () => GetDoctorSetupOptions(sl<DoctorOnboardingRepository>()),
    )
    ..registerLazySingleton<ParseMedicalCertificate>(
      () => ParseMedicalCertificate(sl<DoctorOnboardingRepository>()),
    )
    ..registerLazySingleton<SubmitDoctorApplication>(
      () => SubmitDoctorApplication(sl<DoctorOnboardingRepository>()),
    )
    ..registerLazySingleton<WatchApplicationStatus>(
      () => WatchApplicationStatus(sl<DoctorOnboardingRepository>()),
    )
    ..registerLazySingleton<ManagePracticeSetup>(
      () => ManagePracticeSetup(sl<DoctorOnboardingRepository>()),
    )
    ..registerLazySingleton<ManageAvailability>(
      () => ManageAvailability(sl<DoctorOnboardingRepository>()),
    )
    // --- Doctor onboarding: presentation ------------------------------------
    ..registerFactory<DoctorSetupController>(
      () => DoctorSetupController(
        sl<GetDoctorSetupOptions>(),
        sl<ParseMedicalCertificate>(),
        sl<SubmitDoctorApplication>(),
      ),
    )
    ..registerFactory<ApplicationStatusController>(
      () => ApplicationStatusController(sl<WatchApplicationStatus>()),
    )
    ..registerFactory<PracticeSetupController>(
      () => PracticeSetupController(sl<ManagePracticeSetup>()),
    )
    ..registerFactory<AvailabilityController>(
      () => AvailabilityController(sl<ManageAvailability>()),
    )
    // --- Doctor profile -----------------------------------------------------
    ..registerFactory<DoctorProfileController>(
      () => DoctorProfileController(
        sl<ManageDoctorDashboard>(),
        sl<ManageAvailability>(),
        sl<ManagePracticeSetup>(),
        sl<SignOut>(),
        // The photo only. Everything else on the doctor's profile is edited on
        // its own screen, behind `DoctorProfileEditController`.
        sl<ManageDoctorProfile>(),
        sl<ProfilePhotoPicker>(),
      ),
    )
    // --- Appointments -------------------------------------------------------
    // One slice for both roles. A patient's list and a doctor's list are the
    // same rows read from opposite ends, and the audience is the screen's to
    // choose — see `AppointmentAudience`.
    ..registerLazySingleton<AppointmentRemoteDataSource>(
      () => switch (backend) {
        AppBackend.fake => const FakeAppointmentRemoteDataSource(),
        AppBackend.live => ApiAppointmentRemoteDataSource(sl<ApiClient>()),
      },
    )
    ..registerLazySingleton<AppointmentRepository>(
      () => AppointmentRepositoryImpl(sl<AppointmentRemoteDataSource>()),
    )
    ..registerLazySingleton<GetAppointments>(
      () => GetAppointments(sl<AppointmentRepository>()),
    )
    // --- Doctor practice: data ----------------------------------------------
    // What a doctor manages *after* approval — their profile, their patients,
    // their earnings and where they are paid. Distinct from
    // `DoctorOnboardingRepository`, which is the registration and the review.
    ..registerLazySingleton<DoctorPracticeRemoteDataSource>(
      () => switch (backend) {
        AppBackend.fake => FakeDoctorPracticeRemoteDataSource(),
        AppBackend.live => ApiDoctorPracticeRemoteDataSource(sl<ApiClient>()),
      },
    )
    ..registerLazySingleton<DoctorPracticeRepository>(
      () => DoctorPracticeRepositoryImpl(sl<DoctorPracticeRemoteDataSource>()),
    )
    // --- Doctor practice: domain --------------------------------------------
    ..registerLazySingleton<ManageDoctorProfile>(
      () => ManageDoctorProfile(sl<DoctorPracticeRepository>()),
    )
    ..registerLazySingleton<GetDoctorPatients>(
      () => GetDoctorPatients(sl<DoctorPracticeRepository>()),
    )
    ..registerLazySingleton<GetPatientDetail>(
      () => GetPatientDetail(sl<DoctorPracticeRepository>()),
    )
    ..registerLazySingleton<GetDoctorReviews>(
      () => GetDoctorReviews(sl<DoctorPracticeRepository>()),
    )
    ..registerLazySingleton<GetDoctorEarnings>(
      () => GetDoctorEarnings(sl<DoctorPracticeRepository>()),
    )
    ..registerLazySingleton<ManageBankAccount>(
      () => ManageBankAccount(sl<DoctorPracticeRepository>()),
    )
    ..registerLazySingleton<GetDoctorCredentials>(
      () => GetDoctorCredentials(sl<DoctorPracticeRepository>()),
    )
    ..registerLazySingleton<ManageDoctorSettings>(
      () => ManageDoctorSettings(sl<DoctorPracticeRepository>()),
    )
    // --- Doctor practice: presentation --------------------------------------
    ..registerFactory<DoctorProfileEditController>(
      () => DoctorProfileEditController(sl<ManageDoctorProfile>()),
    )
    ..registerFactory<DoctorReviewsController>(
      () => DoctorReviewsController(sl<GetDoctorReviews>()),
    )
    ..registerFactory<DoctorPatientsController>(
      () => DoctorPatientsController(sl<GetDoctorPatients>()),
    )
    ..registerFactory<DoctorEarningsController>(
      () => DoctorEarningsController(sl<GetDoctorEarnings>()),
    )
    ..registerFactory<BankAccountController>(
      () => BankAccountController(sl<ManageBankAccount>()),
    )
    ..registerFactory<DoctorCredentialsController>(
      () => DoctorCredentialsController(
        sl<GetDoctorCredentials>(),
        sl<ManageDoctorProfile>(),
        sl<CertificatePicker>(),
      ),
    )
    ..registerFactory<DoctorSettingsController>(
      () => DoctorSettingsController(sl<ManageDoctorSettings>()),
    )
    // --- Doctors: data ------------------------------------------------------
    ..registerLazySingleton<DoctorRemoteDataSource>(
      () => switch (backend) {
        AppBackend.fake => const FakeDoctorRemoteDataSource(),
        AppBackend.live => ApiDoctorRemoteDataSource(sl<ApiClient>()),
      },
    )
    ..registerLazySingleton<DoctorRepository>(
      () => DoctorRepositoryImpl(sl<DoctorRemoteDataSource>()),
    )
    // --- Doctors: domain ----------------------------------------------------
    ..registerLazySingleton<GetDoctors>(
      () => GetDoctors(sl<DoctorRepository>()),
    )
    // --- Doctors: presentation ----------------------------------------------
    ..registerLazySingleton<GetDoctorProfile>(
      () => GetDoctorProfile(sl<DoctorRepository>()),
    )
    ..registerFactory<DoctorListController>(
      () => DoctorListController(sl<GetDoctors>()),
    )
    // --- Notifications ------------------------------------------------------
    // Server-side now, which is the whole point of it. In memory it worked
    // exactly once and only ever for the phone that did the booking: the list
    // lived in this process, so it died on restart, never reached the doctor's
    // handset, and no push could be sent from it because nothing outside the
    // app had ever heard of the appointment. The API writes both sides' rows
    // when the booking is stored and pushes each one as it comes due.
    //
    // The fake backend keeps the in-memory one — there is no server to ask.
    ..registerLazySingleton<NotificationRemoteDataSource>(
      () => switch (backend) {
        AppBackend.fake => InMemoryNotificationRemoteDataSource(),
        AppBackend.live => ApiNotificationRemoteDataSource(sl<ApiClient>()),
      },
    )
    ..registerLazySingleton<NotificationRepository>(
      () => NotificationRepositoryImpl(sl<NotificationRemoteDataSource>()),
    )
    ..registerLazySingleton<GetNotifications>(
      () => GetNotifications(sl<NotificationRepository>()),
    )
    ..registerLazySingleton<MarkNotificationsRead>(
      () => MarkNotificationsRead(sl<NotificationRepository>()),
    )
    ..registerLazySingleton<AnnounceBooking>(
      () => AnnounceBooking(sl<NotificationRepository>()),
    )
    // How the doctor learns a patient booked them: their own appointments read
    // is the first place their app sees it, with no push in the picture yet.
    ..registerLazySingleton<AnnounceAppointments>(
      () => AnnounceAppointments(sl<AnnounceBooking>()),
    )
    // A factory, not a singleton: the page owns its controller and disposes it,
    // and a shared one would be disposed the first time the page closed.
    ..registerFactory<NotificationsController>(
      () => NotificationsController(
        sl<GetNotifications>(),
        sl<MarkNotificationsRead>(),
      ),
    )
    // --- Scheduling: data ---------------------------------------------------
    // Asks the API for the doctor's real hours and falls back to sample ones
    // only on a 404 — so the day `GET /doctors/{id}/schedule` ships, the slots
    // a patient sees become the slots the doctor actually set, with no change
    // here. See `ResilientScheduleRemoteDataSource` for why that is not simply
    // the stub.
    ..registerLazySingleton<ScheduleRemoteDataSource>(
      () => switch (backend) {
        AppBackend.fake => const FakeScheduleRemoteDataSource(),
        AppBackend.live => ResilientScheduleRemoteDataSource(
          primary: ApiScheduleRemoteDataSource(sl<ApiClient>()),
          fallback: const FakeScheduleRemoteDataSource(),
        ),
      },
    )
    ..registerLazySingleton<ScheduleRepository>(
      () => ScheduleRepositoryImpl(sl<ScheduleRemoteDataSource>()),
    )
    // --- Scheduling: domain -------------------------------------------------
    ..registerLazySingleton<GetDoctorSchedule>(
      () => GetDoctorSchedule(sl<ScheduleRepository>()),
    )
    // --- Scheduling: presentation -------------------------------------------
    ..registerFactory<ScheduleConsultationController>(
      () => ScheduleConsultationController(sl<GetDoctorSchedule>()),
    )
    // --- Payment: data ------------------------------------------------------
    // The API prices the consultation, creates the Razorpay order and verifies
    // the signature afterwards. All three have to be the server's job: the
    // amount because a client that names its own price names one rupee, and the
    // verification because it needs the key secret, which cannot ship in an APK.
    ..registerLazySingleton<PaymentRemoteDataSource>(
      () => switch (backend) {
        AppBackend.fake => const FakePaymentRemoteDataSource(),
        AppBackend.live => ApiPaymentRemoteDataSource(sl<ApiClient>()),
      },
    )
    // Razorpay's checkout when a key is configured, a stand-in otherwise. The
    // fallback is what keeps the booking flow walkable in a build with no key
    // and under test, where there is no activity for the SDK to open.
    ..registerLazySingleton<PaymentGateway>(
      () => switch (backend) {
        AppBackend.fake => const SimulatedPaymentGateway(),
        AppBackend.live when AppConfig.hasPaymentGateway =>
          RazorpayPaymentGateway(sl<AuthSession>()),
        // A release build with no live key compiled in still takes real
        // payments: the server names the key on every order, and that key is
        // the one checkout opens with. Only a link (below) replaces Razorpay.
        AppBackend.live when kReleaseMode && !AppConfig.hasPaymentLink =>
          RazorpayPaymentGateway(sl<AuthSession>()),
        // A configured payment link, opened in an in-app browser. Second
        // choice on purpose — see `PaymentLinkGateway` for why a link cannot
        // bill per consultation — but it does open the real Razorpay page.
        AppBackend.live when AppConfig.hasPaymentLink =>
          const PaymentLinkGateway(),
        // **Refuses rather than simulates.** This was the stand-in, and the
        // stand-in says "paid" instantly: a live build with no key booked the
        // slot, wrote the confirmation and buzzed the patient's phone without
        // opening a sheet or taking a rupee. It read as "Razorpay will not
        // open"; it was the app giving consultations away.
        AppBackend.live => const UnconfiguredPaymentGateway(),
      },
    )
    ..registerLazySingleton<PaymentRepository>(
      () => PaymentRepositoryImpl(
        sl<PaymentRemoteDataSource>(),
        sl<PaymentGateway>(),
      ),
    )
    // --- Payment: domain ----------------------------------------------------
    ..registerLazySingleton<GetPaymentSummary>(
      () => GetPaymentSummary(sl<PaymentRepository>()),
    )
    ..registerLazySingleton<VerifyUpiId>(
      () => VerifyUpiId(sl<PaymentRepository>()),
    )
    ..registerLazySingleton<PayForConsultation>(
      () => PayForConsultation(sl<PaymentRepository>()),
    )
    // --- Payment: presentation ----------------------------------------------
    ..registerFactory<PaymentController>(
      () => PaymentController(
        sl<GetPaymentSummary>(),
        sl<VerifyUpiId>(),
        sl<PayForConsultation>(),
        sl<StartInstantConsultation>(),
        // Asked of the gateway this build actually resolved, so the screen and
        // the thing that will collect the money cannot disagree about who is
        // asking for the payment method.
        gatewayCollectsMethod: sl<PaymentGateway>().collectsMethodItself,
      ),
    )
    // --- Call ---------------------------------------------------------------
    // A factory, one per call screen. Shared, a rejoin's new screen and the
    // old one closing behind it drove the same peer connection — the old
    // screen's teardown hung up the new call, and cleared its renderers.
    ..registerFactory<CallRepository>(
      () => CallRepositoryImpl(
        WebRtcMediaService(CallSignallingClient(sl<ApiClient>())),
      ),
    )
    // The one call in progress, outliving its screen — see `ActiveCall`.
    ..registerLazySingleton<ActiveCall>(
      () => ActiveCall(() => sl<CallController>()),
    )
    ..registerFactory<CallController>(
      () => CallController(
        sl<CallRepository>(),
        // Opens and closes the consultation record around the call. A call
        // opened from outside the instant flow carries no consultation id, in
        // which case this is never reached.
        sl<ManageConsultationCall>(),
      ),
    );
}
