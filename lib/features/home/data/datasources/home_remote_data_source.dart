import '../../../appointments/domain/entities/appointment.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/doctor_appointment.dart';
import '../../domain/entities/doctor_dashboard.dart';
import '../../domain/entities/home_feed.dart';
import '../../domain/entities/patient_dashboard.dart';
import '../../../profile/domain/entities/medical_history.dart';
import '../../../doctors/domain/entities/speciality.dart';

/// Supplies what the home screens render.
abstract interface class HomeRemoteDataSource {
  Future<HomeFeed> fetchHomeFeed();

  /// The patient's own numbers and state — separate from the catalogue, which
  /// is the same for everybody.
  Future<PatientDashboard> fetchPatientDashboard();

  Future<DoctorDashboard> fetchDoctorDashboard();

  Future<void> setDoctorOnline(bool isOnline);
}

/// Sample content until the catalogue API exists. Swap for an HTTP
/// implementation — nothing above this layer changes.
class FakeHomeRemoteDataSource implements HomeRemoteDataSource {
  FakeHomeRemoteDataSource();

  /// Stand-in for the specialities a patient has consulted.
  ///
  /// **Not a catalogue any more.** This used to be shared with the API
  /// implementation as the row of tiles every patient saw — the same four for
  /// everybody, headed "Popular Specialities", and shown to somebody on the day
  /// they installed the app as though it described them. The real ones come off
  /// the patient's own dashboard now; this is what the offline build puts there
  /// so the section has something to draw.
  static const List<Speciality> specialities = [
    Speciality(
      id: 'general',
      name: 'General',
      practitionerTitle: 'General Physician',
      symbol: SpecialitySymbol.general,
    ),
    Speciality(
      id: 'dentistry',
      name: 'Dentist',
      practitionerTitle: 'Dentist',
      symbol: SpecialitySymbol.dentistry,
    ),
    Speciality(
      id: 'cardiology',
      name: 'Cardio',
      practitionerTitle: 'Cardiologist',
      symbol: SpecialitySymbol.cardiology,
    ),
    Speciality(
      id: 'paediatrics',
      name: 'Pediatrics',
      practitionerTitle: 'Pediatrician',
      symbol: SpecialitySymbol.paediatrics,
    ),
  ];

  /// Held for the run so the dial stays where the doctor left it.
  bool _isDoctorOnline = true;

  @override
  Future<HomeFeed> fetchHomeFeed() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    return const HomeFeed(
      // Left null: the greeting name is read from the patient's own record and
      // overlaid by the controller, so a value here would only be discarded.
      patientFirstName: null,
      specialities: specialities,
      doctors: [
        Doctor(
          id: 'sunita-rao',
          name: 'Dr. Sunita Rao',
          speciality: 'Pediatrician',
          yearsOfExperience: 12,
          rating: 4.9,
          consultationFee: 600,
          isVerified: true,
        ),
        Doctor(
          id: 'vinay-kumar',
          name: 'Dr. Vinay Kumar',
          speciality: 'Cardiologist',
          yearsOfExperience: 15,
          rating: 4.8,
          consultationFee: 900,
          isVerified: true,
        ),
      ],
    );
  }

  @override
  Future<PatientDashboard> fetchPatientDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final now = DateTime.now();

    return PatientDashboard(
      patientName: 'Alexander Wright',
      firstName: 'Alexander',
      profileComplete: true,
      consultations: 6,
      doctorsSeen: 3,
      spend: 4200,
      profileCompleteness: 83,
      // What this sample patient has consulted, which is what the real
      // dashboard answers with. Fewer than four on purpose: the row is
      // whatever the patient has, not a grid to fill.
      specialities: specialities.take(3).toList(),
      recent: [
        Appointment(
          id: 'appointment-done',
          // Deliberately not one of the two doctors in the feed above: a
          // recent consultation and a listing card carrying the same name
          // makes every 'findsOneWidget' in the tests ambiguous, and hides
          // whichever of the two sections is actually broken.
          counterpartName: 'Dr. Anita Desai',
          counterpartSubtitle: 'General Physician',
          mode: ConsultationMode.audio,
          status: AppointmentStatus.completed,
          requestedAt: now.subtract(const Duration(days: 2, minutes: 30)),
          startedAt: now.subtract(const Duration(days: 2, minutes: 29)),
          endedAt: now.subtract(const Duration(days: 2, minutes: 17)),
          durationSeconds: 720,
          fee: 900,
          rating: 5,
        ),
      ],
      medicalHistory: MedicalHistory(
        conditions: const ['Asthma', 'Seasonal Allergies'],
        medications: const ['Albuterol Inhaler'],
        allergies: const ['Penicillin'],
        lastUpdated: DateTime(2024, 10, 12),
      ),
    );
  }

  @override
  Future<DoctorDashboard> fetchDoctorDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final now = DateTime.now();

    /// A time [minutes] from now, kept inside today.
    ///
    /// Genuinely relative, which the old fixed hours only claimed to be: they
    /// were 10:30, 11:15 and 12:00 on today's date, so a doctor opening the
    /// demo at three in the afternoon saw a schedule that had already happened.
    /// That was invisible while a booked appointment could never be joined; now
    /// that one becomes joinable as its time comes round, a past slot would
    /// offer Start Call on a consultation nobody could be in.
    ///
    /// Clamped to the last minute of the day so the rows stay under today's
    /// heading. Late enough at night the clamp bunches them, which is a stub
    /// looking odd rather than anything the app does.
    DateTime at(int minutes) {
      final dayEnd = DateTime(now.year, now.month, now.day, 23, 59);
      final when = now.add(Duration(minutes: minutes));

      return when.isBefore(dayEnd) ? when : dayEnd;
    }

    return DoctorDashboard(
      // The real endpoint returns these from the signed-in doctor's profile.
      doctorName: 'Dr. Amit Verma',
      speciality: 'Cardiologist',
      isOnline: _isDoctorOnline,
      stats: const DoctorDayStats(
        consults: 18,
        patients: 24,
        rating: 4.8,
        earningsToday: 12600,
        completedTotal: 342,
      ),
      appointments: [
        DoctorAppointment(
          id: 'appointment-1',
          patientName: 'Rahul Sharma',
          // Matches a row in the practice stub, so tapping the name in an
          // offline build reaches a patient that exists.
          patientId: 'patient-1',
          mode: ConsultationMode.video,
          // Now: a patient actually on the line, which is the one row that
          // offers Start Call.
          startsAt: at(0),
          status: DoctorAppointmentStatus.waiting,
          concern: 'Chest tightness when climbing stairs for the past week.',
        ),
        DoctorAppointment(
          id: 'appointment-2',
          patientName: 'Patient Hawk',
          mode: ConsultationMode.audio,
          startsAt: at(45),
          status: DoctorAppointmentStatus.confirmed,
          kind: AppointmentKind.scheduled,
          isAnonymous: true,
          // The only thing the doctor is told about an anonymous patient, and
          // the reason the card carries one at all.
          concern: 'Would like to discuss stress and anxiety management.',
        ),
        // Tomorrow, so the offline build exercises the day grouping. The
        // dashboard used to show the rest of the current day and nothing else,
        // and a stub that only ever returned today could not have shown it.
        DoctorAppointment(
          id: 'appointment-4',
          patientName: 'Arjun Nair',
          mode: ConsultationMode.video,
          startsAt: DateTime(now.year, now.month, now.day + 1, 9, 30),
          status: DoctorAppointmentStatus.confirmed,
          kind: AppointmentKind.scheduled,
        ),
        DoctorAppointment(
          id: 'appointment-3',
          patientName: 'Meera Iyer',
          patientId: 'patient-2',
          mode: ConsultationMode.video,
          startsAt: at(90),
          status: DoctorAppointmentStatus.confirmed,
          kind: AppointmentKind.scheduled,
        ),
      ],
    );
  }

  @override
  Future<void> setDoctorOnline(bool isOnline) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _isDoctorOnline = isOnline;
  }
}
