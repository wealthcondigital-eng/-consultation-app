import 'booking_call.dart';
import 'consultation_flow.dart';
import 'core_home.dart';
import 'doctor_onboarding.dart';
import 'doctor_practice.dart';
import 'profile.dart';

/// Every Hindi string, merged from one table per area of the app.
///
/// Split by area so they can be edited independently. A key in two tables is
/// fine as long as both say the same thing; the later one wins.
final Map<String, String> hindiStrings = {
  ...hiCoreHome,
  ...hiProfile,
  ...hiDoctorPractice,
  ...hiDoctorOnboarding,
  ...hiConsultationFlow,
  ...hiBookingCall,
};
