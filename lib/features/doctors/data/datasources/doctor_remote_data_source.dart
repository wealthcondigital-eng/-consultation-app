import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../domain/entities/doctor.dart';

/// Supplies the doctor catalogue.
abstract interface class DoctorRemoteDataSource {
  Future<List<Doctor>> fetchDoctors({
    String? specialityId,

    /// True for the instant flow: list only doctors who can answer right now.
    bool availableNow,
  });

  /// One doctor in full: their description, qualifications, languages and the
  /// figures behind the star.
  ///
  /// A separate read from the listing on purpose. The list endpoint returns
  /// fifty rows and a paragraph each would be a payload nobody reads; the
  /// profile is fetched when somebody actually asks to look at one.
  ///
  /// Returns null when there is no such doctor, which the detail screen shows
  /// as the listing row it was already handed rather than as an error.
  Future<Doctor?> fetchDoctor(String id);
}

/// Sample catalogue until the directory API exists. Swap for an HTTP
/// implementation — nothing above this layer changes.
class FakeDoctorRemoteDataSource implements DoctorRemoteDataSource {
  const FakeDoctorRemoteDataSource();

  /// Keyed by speciality id, which is how the real endpoint filters.
  static const Map<String, List<Doctor>> _bySpeciality = {
    'cardiology': [
      Doctor(
        id: 'amit-verma',
        name: 'Dr. Amit Verma',
        speciality: 'Senior Cardiologist',
        yearsOfExperience: 15,
        rating: 4.9,
        consultationFee: 800,
        audioConsultationFee: 600,
        isVerified: true,
        isAvailableNow: true,
        registrationNumber: 'MH-2011-04871',
      ),
      Doctor(
        id: 'sarah-dsouza',
        name: "Dr. Sarah D'Souza",
        speciality: 'Interventional Cardiologist',
        yearsOfExperience: 10,
        rating: 4.8,
        consultationFee: 1000,
        audioConsultationFee: 750,
        isVerified: true,
        isAvailableNow: true,
        // Voice only while she is on the ward.
        supportedModes: {ConsultationMode.audio},
      ),
    ],
    'paediatrics': [
      Doctor(
        id: 'sunita-rao',
        name: 'Dr. Sunita Rao',
        speciality: 'Pediatrician',
        yearsOfExperience: 12,
        rating: 4.9,
        consultationFee: 600,
        audioConsultationFee: 450,
        isVerified: true,
        isAvailableNow: true,
      ),
    ],
    'general': [
      Doctor(
        id: 'rahul-menon',
        name: 'Dr. Rahul Menon',
        speciality: 'General Physician',
        yearsOfExperience: 8,
        rating: 4.7,
        consultationFee: 400,
        audioConsultationFee: 300,
        isVerified: true,
        isAvailableNow: true,
      ),
    ],
    'dentistry': [
      Doctor(
        id: 'neha-gupta',
        name: 'Dr. Neha Gupta',
        speciality: 'Dental Surgeon',
        yearsOfExperience: 9,
        rating: 4.6,
        consultationFee: 500,
        audioConsultationFee: 400,
        isVerified: true,
        // A dentist needs to see the tooth.
        supportedModes: {ConsultationMode.video},
      ),
    ],
  };

  @override
  Future<List<Doctor>> fetchDoctors({
    String? specialityId,
    bool availableNow = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (specialityId == null) {
      return _bySpeciality.values.expand((doctors) => doctors).toList();
    }
    return _bySpeciality[specialityId] ?? const [];
  }

  @override
  Future<Doctor?> fetchDoctor(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final row = _bySpeciality.values
        .expand((doctors) => doctors)
        .where((doctor) => doctor.id == id)
        .firstOrNull;

    if (row == null) return null;

    // The long form, so the offline build exercises the detail screen rather
    // than rendering a listing row under a heading that promises more.
    return row.mergedWith(
      Doctor(
        id: row.id,
        name: row.name,
        speciality: row.speciality,
        yearsOfExperience: row.yearsOfExperience,
        rating: row.rating,
        consultationFee: row.consultationFee,
        audioConsultationFee: row.audioConsultationFee,
        isVerified: row.isVerified,
        isAvailableNow: row.isAvailableNow,
        supportedModes: row.supportedModes,
        about:
            '${row.name} has ${row.yearsOfExperience} years of practice in '
            '${row.speciality.toLowerCase()}. Consultations cover diagnosis, '
            'second opinions, medication reviews and follow-ups, with a '
            'prescription issued where one is appropriate.',
        qualifications: const ['MBBS', 'MD'],
        languages: const ['English', 'Hindi'],
        consultationsDone: 480 + row.yearsOfExperience * 37,
        reviewCount: 120 + row.yearsOfExperience * 11,
      ),
    );
  }
}
