/// Where a doctor's registration has got to.
enum DoctorApplicationStatus {
  /// Still being filled in.
  draft,

  /// Submitted and waiting on the medical board check.
  underReview,

  approved,
  rejected,
}

/// A submitted doctor registration.
class DoctorApplication {
  const DoctorApplication({
    required this.id,
    required this.status,
    this.submittedAt,
    this.rejectionReason,
  });

  final String id;
  final DoctorApplicationStatus status;
  final DateTime? submittedAt;

  /// Set when [status] is rejected, so the doctor knows what to fix.
  final String? rejectionReason;

  bool get isUnderReview => status == DoctorApplicationStatus.underReview;
  bool get isApproved => status == DoctorApplicationStatus.approved;
  bool get isRejected => status == DoctorApplicationStatus.rejected;
}
