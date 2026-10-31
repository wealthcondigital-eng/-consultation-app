import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/doctor_review.dart';
import 'admin_remote_data_source.dart';

/// The consultation API as the review queue.
///
/// Replaces the Supabase implementation. What the RLS policies used to do —
/// widen a doctor's own-row-only read to the whole table once `is_admin()` is
/// true — is now an admin guard on the API routes. The authority has moved, not
/// disappeared: this class sends a bearer token and the server decides, exactly
/// as before, and a non-admin gets an empty queue rather than an error.
///
/// The same endpoints the Next.js console in `admin/` calls, so there is one
/// server-side contract rather than two. The phone app keeps the shorter
/// application-level view of it; per-document review lives in the console,
/// where there is room to read a document properly.
class ApiAdminRemoteDataSource implements AdminRemoteDataSource {
  const ApiAdminRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  Future<bool> isAdmin() async {
    // A probe, and the only caller — `IsAdmin` — already treats any failure as
    // "not an admin". Sent as one, so it cannot also end the session: this runs
    // on every launch and immediately after every sign-in, ahead of the lookups
    // that decide where the user goes, and a route that refuses a non-admin
    // with a 401 rather than a 403 would otherwise sign out every ordinary user
    // the moment they got in. A session that really is dead is still caught —
    // by the very next lookup, which reads the answer instead of shrugging.
    final body = await _client.get('/admin/me', signalsExpiry: false);
    return body['isAdmin'] == true;
  }

  @override
  Future<List<DoctorReview>> fetchPendingDoctors() async {
    // Oldest first is the server's job — a queue that reorders itself leaves
    // the earliest applicant waiting longest, and two clients sorting it
    // separately is how they come to disagree.
    final body = await _client.get('/admin/doctors?status=under_review');

    final doctors = body['doctors'];
    if (doctors is! List) return const [];

    return doctors
        .whereType<Map<String, Object?>>()
        .map(_toReview)
        .toList(growable: false);
  }

  DoctorReview _toReview(Map<String, Object?> json) {
    final submittedAt = json['submittedAt'] as String?;

    return DoctorReview(
      doctorId: json['doctorId'] as String? ?? json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? 'Unnamed applicant',
      submittedAt: submittedAt == null ? null : DateTime.tryParse(submittedAt)?.toLocal(),
      medicalDegree: json['medicalDegree'] as String?,
      registrationNumber: json['registrationNumber'] as String?,
      specialty: json['specialty'] as String?,
      state: json['state'] as String?,
      city: json['city'] as String?,
      yearsOfExperience: (json['yearsOfExperience'] as num?)?.toInt(),
      certificatePath: json['certificatePath'] as String?,
      certificateName: json['certificateName'] as String?,
      phone: json['phone'] as String?,
    );
  }

  @override
  Future<void> approve(String doctorId) async {
    await _client.post(
      '/admin/doctors/${Uri.encodeComponent(doctorId)}/approve',
    );
  }

  @override
  Future<void> reject(String doctorId, String reason) async {
    await _client.post(
      '/admin/doctors/${Uri.encodeComponent(doctorId)}/reject',
      body: {'reason': reason},
    );
  }

  @override
  Future<String> certificateUrl(String storagePath) async {
    // The bucket is private, so a presigned link minted by the API is the only
    // way to open a certificate. Requested per view and never cached: it
    // expires in minutes, and a copied URL should not outlive the review.
    final body = await _client.post(
      '/admin/certificate-url',
      body: {'path': storagePath},
    );

    final url = body['url'];
    if (url is! String || url.isEmpty) {
      throw const Failure('That certificate could not be opened.');
    }

    return url;
  }
}
