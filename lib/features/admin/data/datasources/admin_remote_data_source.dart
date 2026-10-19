import '../../domain/entities/doctor_review.dart';

/// Talks to the backend that holds the review queue.
abstract interface class AdminRemoteDataSource {
  Future<bool> isAdmin();

  Future<List<DoctorReview>> fetchPendingDoctors();

  Future<void> approve(String doctorId);

  Future<void> reject(String doctorId, String reason);

  Future<String> certificateUrl(String storagePath);
}

/// Stand-in with a two-doctor queue, so the screen is walkable without a
/// backend.
///
/// Reports the signed-in user as *not* an administrator. Answering true would
/// route every stubbed session to the review queue and quietly break patient
/// and doctor sign-in; the queue is reached by its route instead.
class FakeAdminRemoteDataSource implements AdminRemoteDataSource {
  FakeAdminRemoteDataSource();

  final List<DoctorReview> _pending = [
    DoctorReview(
      doctorId: 'doctor-1',
      fullName: 'Dr. Sarah Jenkins',
      submittedAt: DateTime(2026, 8, 18, 9, 30),
      medicalDegree: 'MD - General Medicine',
      registrationNumber: 'REG-9920-A',
      specialty: 'Internal Medicine',
      state: 'Maharashtra',
      city: 'Mumbai',
      yearsOfExperience: 8,
      certificatePath: 'doctor-1/medical-certificate.pdf',
      certificateName: 'medical-certificate.pdf',
      phone: '+91 98765 43210',
    ),
    DoctorReview(
      doctorId: 'doctor-2',
      fullName: 'Dr. Vinay Kumar',
      submittedAt: DateTime(2026, 8, 19, 14, 5),
      medicalDegree: 'MD - Cardiology',
      registrationNumber: 'REG-4471-C',
      specialty: 'Cardiology',
      state: 'Karnataka',
      city: 'Bengaluru',
      yearsOfExperience: 15,
      // Filled the form by hand, which the reviewer should be able to tell.
      phone: '+91 91234 56789',
    ),
  ];

  @override
  Future<bool> isAdmin() async => false;

  @override
  Future<List<DoctorReview>> fetchPendingDoctors() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return List.unmodifiable(_pending);
  }

  @override
  Future<void> approve(String doctorId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _pending.removeWhere((review) => review.doctorId == doctorId);
  }

  @override
  Future<void> reject(String doctorId, String reason) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _pending.removeWhere((review) => review.doctorId == doctorId);
  }

  @override
  Future<String> certificateUrl(String storagePath) async =>
      'https://example.invalid/$storagePath';
}
