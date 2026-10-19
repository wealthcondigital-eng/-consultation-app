import '../entities/doctor_dashboard.dart';
import '../entities/home_feed.dart';
import '../entities/patient_dashboard.dart';

/// Contract for what the two home screens render.
abstract interface class HomeRepository {
  /// The patient's greeting, specialities and doctor list, in one call.
  Future<HomeFeed> fetchHomeFeed();

  /// The patient's own numbers, live consultation and recent history.
  Future<PatientDashboard> fetchPatientDashboard();

  /// The doctor's presence, day figures and upcoming consultations.
  Future<DoctorDashboard> fetchDoctorDashboard();

  /// Turns the doctor's availability for instant consultations on or off.
  Future<void> setDoctorOnline(bool isOnline);
}
