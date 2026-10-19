import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/entities/speciality.dart';

/// Everything the patient home screen renders, fetched in one call.
class HomeFeed {
  const HomeFeed({
    required this.patientFirstName,
    required this.specialities,
    required this.doctors,
  });

  const HomeFeed.empty()
    : patientFirstName = null,
      specialities = const [],
      doctors = const [];

  /// Null until the patient has completed their profile — the greeting falls
  /// back to a generic one.
  final String? patientFirstName;

  final List<Speciality> specialities;
  final List<Doctor> doctors;

  /// The feed with the greeting name overlaid.
  ///
  /// The name comes from the patient's own record rather than the feed, so it
  /// is applied after the fact instead of being fetched twice.
  HomeFeed withPatientFirstName(String? name) => HomeFeed(
    patientFirstName: name,
    specialities: specialities,
    doctors: doctors,
  );

  /// `Hello, Rahul` / `Hello there`
  String get greeting =>
      patientFirstName == null ? 'Hello there' : 'Hello, $patientFirstName';
}
