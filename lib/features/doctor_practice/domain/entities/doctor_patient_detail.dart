import 'doctor_earnings.dart';
import 'doctor_patient.dart';

/// One patient, with what this doctor has seen them for.
///
/// The pair's history and nothing wider. A doctor has no business reading what
/// somebody was consulted about elsewhere, so this is built from their own
/// consultation rows rather than from the patient's record — which is also why
/// there is no medical history on it. The app has never held one.
class DoctorPatientDetail {
  const DoctorPatientDetail({required this.patient, this.history = const []});

  final DoctorPatient patient;

  /// Their completed consultations with this doctor, newest first.
  ///
  /// The same rows the earnings screen is built from, which is why they are
  /// [EarningsEntry]s: a consultation and what it was billed at are one fact,
  /// and a second entity for the same row would be a second thing to keep in
  /// step with the API.
  final List<EarningsEntry> history;

  bool get hasHistory => history.isNotEmpty;
}
