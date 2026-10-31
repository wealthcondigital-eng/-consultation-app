import 'package:flutter/material.dart';

import '../../features/anonymous/presentation/screens/anonymous_booking_screen.dart';
import '../../features/admin/presentation/screens/admin_queue_screen.dart';
import '../../features/appointments/domain/entities/appointment.dart';
import '../../features/appointments/presentation/screens/appointments_screen.dart';
import '../../features/appointments/presentation/screens/consultation_receipt_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/call/presentation/screens/call_screen.dart';
import '../../features/recordings/presentation/screens/recording_player_screen.dart';
import '../../features/recordings/presentation/screens/recordings_chat_screen.dart';
import '../../features/recordings/presentation/screens/recordings_screen.dart';
import '../../features/consultation/presentation/screens/consult_options_screen.dart';
import '../../features/doctor_onboarding/domain/entities/doctor_application.dart';
import '../../features/doctor_onboarding/domain/entities/doctor_availability.dart';
import '../../features/doctor_onboarding/presentation/screens/application_approved_screen.dart';
import '../../features/doctor_onboarding/presentation/screens/application_pending_screen.dart';
import '../../features/doctor_onboarding/presentation/screens/doctor_profile_setup_screen.dart';
import '../../features/doctor_onboarding/presentation/screens/practice_setup_screen.dart';
import '../../features/doctor_onboarding/presentation/screens/set_availability_screen.dart';
import '../../features/doctor_onboarding/domain/entities/practice_setup.dart';
import '../../features/doctor_practice/domain/entities/doctor_practice_profile.dart';
import '../../features/doctor_practice/presentation/screens/bank_account_screen.dart';
import '../../features/doctor_practice/presentation/screens/doctor_credentials_screen.dart';
import '../../features/doctor_practice/presentation/screens/doctor_earnings_screen.dart';
import '../../features/doctor_practice/presentation/screens/doctor_patients_screen.dart';
import '../../core/widgets/document_viewer_screen.dart';
import '../../features/legal/domain/entities/legal_document.dart';
import '../../features/legal/presentation/screens/contact_support_screen.dart';
import '../../features/legal/presentation/screens/legal_document_screen.dart';
import '../../features/profile/presentation/screens/delete_account_screen.dart';
import '../../features/doctor_practice/presentation/screens/doctor_reviews_screen.dart';
import '../../features/doctor_practice/presentation/screens/doctor_settings_screen.dart';
import '../../features/doctor_practice/presentation/screens/edit_doctor_profile_screen.dart';
import '../../features/doctor_profile/presentation/screens/doctor_profile_screen.dart';
import '../../features/consultation/presentation/screens/doctor_matching_screen.dart';
import '../../features/consultation/presentation/screens/consultation_feedback_screen.dart';
import '../../features/doctors/presentation/screens/doctor_detail_screen.dart';
import '../../features/doctors/presentation/screens/doctor_list_screen.dart';
import '../../features/auth/presentation/screens/phone_login_screen.dart';
import '../../features/home/presentation/screens/doctor_home_screen.dart';
import '../../features/home/presentation/screens/patient_home_screen.dart';
import '../../features/onboarding/domain/entities/user_role.dart';
import '../../features/profile/domain/entities/patient_account.dart';
import '../../features/payment/presentation/screens/payment_screen.dart';
import '../../features/payment/presentation/screens/payment_failed_screen.dart';
import '../../features/payment/presentation/screens/payment_success_screen.dart';
import '../../features/scheduling/presentation/screens/schedule_consultation_screen.dart';
import '../../features/profile/presentation/screens/complete_profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/domain/entities/medical_history.dart';
import '../../features/profile/presentation/screens/medical_history_screen.dart';
import '../../features/profile/presentation/screens/patient_profile_screen.dart';
import '../../features/profile/presentation/screens/patient_settings_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/landing_screen.dart';
import '../../features/startup/presentation/screens/splash_screen.dart';
import 'app_routes.dart';

/// Central route table. Screens are constructed here and nowhere else, so
/// navigation stays decoupled from the widgets that trigger it.
class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.adminQueue:
        return _route(const AdminQueueScreen(), settings);

      case AppRoutes.splash:
        return _route(const SplashScreen(), settings);

      case AppRoutes.landing:
        return _route(const LandingScreen(), settings);

      case AppRoutes.phoneLogin:
        return _route(
          PhoneLoginScreen(role: settings.arguments as UserRole?),
          settings,
        );

      case AppRoutes.otpVerification:
        return _route(
          OtpVerificationScreen(
            args: settings.arguments! as OtpVerificationArgs,
          ),
          settings,
        );

      case AppRoutes.completeProfile:
        return _route(
          CompleteProfileScreen(role: settings.arguments as UserRole?),
          settings,
        );

      case AppRoutes.doctorProfileSetup:
        return _route(const DoctorProfileSetupScreen(), settings);

      case AppRoutes.doctorApplicationPending:
        return _route(
          ApplicationPendingScreen(
            application: settings.arguments! as DoctorApplication,
          ),
          settings,
        );

      case AppRoutes.doctorApplicationApproved:
        return _route(const ApplicationApprovedScreen(), settings);

      case AppRoutes.doctorPracticeSetup:
        // Pops the fees it stored, so the profile row that opened it shows the
        // new summary without a second read. The argument says whether this is
        // a wizard step, because where Continue goes depends on it and the
        // screen must not guess from the navigator stack — during onboarding
        // this sits on top of the approval screen, so `canPop()` is true in
        // both cases.
        return _route<PracticeSetup>(
          PracticeSetupScreen(isWizardStep: settings.arguments == true),
          settings,
        );

      case AppRoutes.doctorAvailability:
        // Pops the schedule it stored, so the profile row that opened it can
        // show the new summary without a second read. The argument decides
        // whether saving hands over to the doctor's home screen or comes back
        // here — see `SetAvailabilityArgs`, and the bug it fixes.
        return _route<DoctorAvailability>(
          SetAvailabilityScreen(
            args:
                settings.arguments as SetAvailabilityArgs? ??
                const SetAvailabilityArgs(),
          ),
          settings,
        );

      case AppRoutes.doctorProfile:
        return _route(const DoctorProfileScreen(), settings);

      case AppRoutes.patientProfile:
        return _route(const PatientProfileScreen(), settings);

      case AppRoutes.editProfile:
        // Pops the stored `PatientAccount` once the edits were saved — or true
        // when the backend sent no record back — so My Profile can update.
        return _route<Object>(
          EditProfileScreen(account: settings.arguments! as PatientAccount),
          settings,
        );

      case AppRoutes.medicalHistory:
        // Pops the record it stored, so the profile card behind shows the new
        // summary without a second read.
        return _route<MedicalHistory>(const MedicalHistoryScreen(), settings);

      case AppRoutes.notifications:
        return _route(const NotificationsScreen(), settings);

      case AppRoutes.patientSettings:
        return _route(const PatientSettingsScreen(), settings);

      case AppRoutes.patientAppointments:
        return _route(
          const AppointmentsScreen(audience: AppointmentAudience.patient),
          settings,
        );

      case AppRoutes.doctorAppointments:
        return _route(
          const AppointmentsScreen(audience: AppointmentAudience.doctor),
          settings,
        );

      case AppRoutes.doctorEditProfile:
        // Pops the stored profile, so the screen behind folds it in rather
        // than re-reading a page the app just wrote.
        return _route<DoctorPracticeProfile>(
          const EditDoctorProfileScreen(),
          settings,
        );

      case AppRoutes.doctorBankAccount:
        return _route(const BankAccountScreen(), settings);

      case AppRoutes.doctorCredentials:
        return _route(const DoctorCredentialsScreen(), settings);

      case AppRoutes.doctorReviews:
        return _route(const DoctorReviewsScreen(), settings);

      case AppRoutes.dataProtection:
        return _route(
          const LegalDocumentScreen(document: LegalDocument.dpdp),
          settings,
        );

      case AppRoutes.privacyPolicy:
        return _route(
          const LegalDocumentScreen(document: LegalDocument.privacyPolicy),
          settings,
        );

      case AppRoutes.termsAndConditions:
        return _route(
          const LegalDocumentScreen(document: LegalDocument.termsAndConditions),
          settings,
        );

      case AppRoutes.cancellationAndRefund:
        return _route(
          const LegalDocumentScreen(
            document: LegalDocument.cancellationAndRefund,
          ),
          settings,
        );

      case AppRoutes.contactSupport:
        return _route(const ContactSupportScreen(), settings);

      case AppRoutes.deleteAccount:
        return _route(const DeleteAccountScreen(), settings);

      case AppRoutes.consultationReceipt:
        return _route(
          ConsultationReceiptScreen(
            appointment: settings.arguments! as Appointment,
          ),
          settings,
        );

      case AppRoutes.documentViewer:
        return _route(
          DocumentViewerScreen(args: settings.arguments! as DocumentViewerArgs),
          settings,
        );

      case AppRoutes.doctorSettings:
        return _route(const DoctorSettingsScreen(), settings);

      case AppRoutes.doctorPatients:
        return _route(const DoctorPatientsScreen(), settings);

      case AppRoutes.doctorEarnings:
        return _route(const DoctorEarningsScreen(), settings);

      case AppRoutes.home:
        return _route(const PatientHomeScreen(), settings);

      case AppRoutes.doctorHome:
        return _route(const DoctorHomeScreen(), settings);

      case AppRoutes.consultOptions:
        return _route(const ConsultOptionsScreen(), settings);

      case AppRoutes.doctorList:
        return _route(
          DoctorListScreen(
            // Absent arguments mean "every doctor".
            args:
                settings.arguments as DoctorListArgs? ?? const DoctorListArgs(),
          ),
          settings,
        );

      case AppRoutes.doctorDetail:
        return _route(
          DoctorDetailScreen(args: settings.arguments! as DoctorDetailArgs),
          settings,
        );

      case AppRoutes.scheduleConsultation:
        return _route(
          ScheduleConsultationScreen(
            args: settings.arguments! as ScheduleConsultationArgs,
          ),
          settings,
        );

      case AppRoutes.payment:
        return _route(
          PaymentScreen(args: settings.arguments! as PaymentArgs),
          settings,
        );

      case AppRoutes.paymentSuccess:
        return _route(
          PaymentSuccessScreen(args: settings.arguments! as PaymentSuccessArgs),
          settings,
        );

      // Typed, because the screen pops a choice and an untyped route would
      // hand `pushNamed<PaymentFailureChoice>` a `Route<dynamic>` it cannot
      // cast — the crash this router's own comment is about.
      case AppRoutes.paymentFailed:
        return _route<PaymentFailureChoice>(
          PaymentFailedScreen(args: settings.arguments! as PaymentFailedArgs),
          settings,
        );

      case AppRoutes.doctorMatching:
        return _route(
          DoctorMatchingScreen(args: settings.arguments! as DoctorMatchingArgs),
          settings,
        );

      case AppRoutes.anonymousBooking:
        return _route(const AnonymousBookingScreen(), settings);

      case AppRoutes.chat:
        return _route(
          RecordingsChatScreen(args: settings.arguments! as RecordingsChatArgs),
          settings,
        );

      case AppRoutes.recordings:
        return _route(const RecordingsScreen(), settings);

      case AppRoutes.recordingPlayer:
        return _route(
          RecordingPlayerScreen(
            args: settings.arguments! as RecordingPlayerArgs,
          ),
          settings,
        );

      case AppRoutes.call:
        return _route(
          CallScreen(args: settings.arguments! as CallArgs),
          settings,
        );

      case AppRoutes.consultationFeedback:
        return _route(
          ConsultationFeedbackScreen(
            args: settings.arguments! as ConsultationFeedbackArgs,
          ),
          settings,
        );

      default:
        return _route(const _UnknownRouteScreen(), settings);
    }
  }

  /// Generic in the pop result, because `Navigator.pushNamed<T>` casts whatever
  /// this returns to `Route<T>`. A screen that pops a value must be built here
  /// with that same type or the cast fails at runtime, not at compile time.
  static MaterialPageRoute<T> _route<T>(Widget child, RouteSettings settings) {
    return MaterialPageRoute<T>(builder: (_) => child, settings: settings);
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Screen not found')));
  }
}
