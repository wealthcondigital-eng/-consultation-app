import '../entities/doctor_review.dart';

/// Contract for reviewing doctor registrations.
abstract interface class AdminRepository {
  /// Whether the signed-in user is on the administrator roster.
  Future<bool> isAdmin();

  /// Registrations waiting on a decision, oldest first — the queue is a queue.
  Future<List<DoctorReview>> fetchPendingDoctors();

  Future<void> approve(String doctorId);

  /// [reason] is required: a rejection the doctor cannot act on is a dead end,
  /// and the database enforces the same rule.
  Future<void> reject(String doctorId, String reason);

  /// A short-lived link to the uploaded certificate, for opening in a viewer.
  Future<String> certificateUrl(String storagePath);
}
