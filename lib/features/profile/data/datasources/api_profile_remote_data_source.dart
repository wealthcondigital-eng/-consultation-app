import '../../../../core/error/failure.dart';
import '../../../../core/logging/auth_logger.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/blood_group.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/medical_history.dart';
import '../../domain/entities/medical_report.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/patient_account.dart';
import 'profile_remote_data_source.dart';

/// The patient record, on the consultation API.
///
/// Replaces the Supabase implementation, which had stopped working: its RLS
/// policies compared the row's key against `auth.jwt()->>'sub'` from a Firebase
/// ID token, and once Firebase was removed there was no token to read, so every
/// call arrived anonymously and came back refused. Moving the record to the API
/// is what fixes that — re-pointing the policies could not, because the token
/// they wanted no longer exists.
///
/// The endpoints, all scoped to the caller by their bearer token rather than by
/// an id in the path — there is no route here that can name another patient:
///
/// | Method | Path                            |
/// | ------ | ------------------------------- |
/// | POST   | /patients/me                    |
/// | GET    | /patients/me                    |
/// | PATCH  | /patients/me                    |
/// | GET    | /patients/me/exists             |
/// | GET    | /patients/me/medical-history    |
/// | PUT    | /patients/me/medical-history    |
/// | GET    | /patients/me/settings           |
/// | PATCH  | /patients/me/settings           |
/// | POST   | /patients/me/photo              | multipart, field `photo`
/// | DELETE | /patients/me/photo              |
///
/// The payload keys stay snake_case for the account routes, because that is
/// what `PatientProfilePayload` and `PatientDetailsPayload` already produce and
/// what their tests assert. The routes added since — the medical record and the
/// settings — are camelCase like the rest of the API; normalising the account
/// ones is a job of its own, app and tests included.
class ApiProfileRemoteDataSource implements ProfileRemoteDataSource {
  const ApiProfileRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  Future<void> savePatientProfile(Map<String, Object?> payload) async {
    // No `id` and no `phone` in the body. Both come off the verified session
    // server-side, which is what stops a patient writing a record keyed to
    // someone else — the guarantee the RLS policy used to give.
    await _client.post('/patients/me', body: payload);

    AuthLogger.event('API · patient profile saved');
  }

  @override
  Future<PatientAccount> fetchAccount() async {
    final body = await _client.get('/patients/me');

    final patient = body['patient'];
    if (patient is! Map<String, Object?>) {
      // Signed in but onboarding never finished — the caller routes back to
      // the complete-profile screen rather than showing an empty account.
      throw const Failure('Your profile is not set up yet.');
    }

    AuthLogger.event('API · patient account read', {
      'full_name': patient['full_name'],
      'email': patient['email'],
      'photo_url': patient['photo_url'],
    });

    return _toAccount(patient);
  }

  @override
  Future<PatientAccount?> updateDetails(Map<String, Object?> payload) async {
    // PATCH, not POST: this edits an existing record, and the fields the
    // patient does not own — their verified phone number above all — are absent
    // from the payload rather than being sent and ignored.
    final body = await _client.patch('/patients/me', body: payload);

    // The server answers with the record as it stored it. That, not the form,
    // is what the profile shows next — so an edit the server dropped shows up
    // as not saved instead of looking saved until the next reload.
    final patient = body['patient'];

    AuthLogger.event('API · patient details updated', {
      'sent full_name': payload['full_name'],
      'stored full_name': patient is Map ? patient['full_name'] : '(no record)',
    });

    return patient is Map<String, Object?> ? _toAccount(patient) : null;
  }

  @override
  Future<bool> hasProfile() async {
    try {
      final body = await _client.get('/patients/me/exists');
      return body['exists'] == true;
    } on Failure catch (failure) {
      if (failure.isNotFound) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<MedicalHistory> fetchMedicalHistory() async {
    final body = await _client.get('/patients/me/medical-history');

    return _toMedicalHistory(body['history']) ?? const MedicalHistory.empty();
  }

  @override
  Future<MedicalHistory> saveMedicalHistory(
    Map<String, Object?> payload,
  ) async {
    // PUT: the form owns every list, so a condition the patient deleted has to
    // actually disappear. A PATCH would merge it back in.
    final body = await _client.put(
      '/patients/me/medical-history',
      body: payload,
    );

    AuthLogger.event('API · medical history saved');

    return _toMedicalHistory(body['history']) ?? const MedicalHistory.empty();
  }

  @override
  Future<NotificationSettings> fetchSettings() async {
    final body = await _client.get('/patients/me/settings');
    return _toSettings(body['settings']);
  }

  @override
  Future<NotificationSettings> updateSettings(
    Map<String, Object?> payload,
  ) async {
    final body = await _client.patch('/patients/me/settings', body: payload);

    return _toSettings(body['settings']);
  }

  @override
  Future<String?> uploadPhoto(String filePath) async {
    final body = await _client.uploadFile(
      '/patients/me/photo',
      field: 'photo',
      filePath: filePath,
      // Declared explicitly. `MultipartFile.fromPath` sniffs nothing, so with
      // no type given the part arrives as `application/octet-stream` — which
      // the store then has to guess about. It guesses from the bytes and gets
      // it right, but saying so is cheaper than making it look.
      contentType: _contentTypeOf(filePath),
    );

    AuthLogger.event('API · profile photo uploaded');

    return body['photo_url'] as String?;
  }

  @override
  Future<List<MedicalReport>> fetchReports() async {
    final body = await _client.get('/patients/me/reports');

    final rows = body['reports'];
    if (rows is! List) return const [];

    return [
      for (final row in rows.whereType<Map<String, Object?>>())
        if (row['id'] is String) _reportFrom(row),
    ];
  }

  @override
  Future<MedicalReport> uploadReport({
    required String filePath,
    required String title,
    MedicalRecordKind kind = MedicalRecordKind.report,
  }) async {
    final body = await _client.uploadFile(
      '/patients/me/reports',
      field: 'report',
      filePath: filePath,
      // Declared rather than sniffed, for the same reason the avatar's is: with
      // nothing given the part arrives as `application/octet-stream`, and the
      // type is what the viewer later decides on.
      contentType: _contentTypeOf(filePath),
      // An API that does not yet know about `kind` ignores the extra field and
      // answers without one, which reads back as an ordinary report. Nothing
      // breaks while the backend catches up.
      fields: {'title': title, 'kind': kind.key},
    );

    final report = body['report'];
    if (report is! Map<String, Object?>) throw const Failure.unexpected();

    AuthLogger.event('API · medical report uploaded');

    return _reportFrom(report);
  }

  @override
  Future<void> deleteReport(String id) =>
      _client.delete('/patients/me/reports/$id');

  static MedicalReport _reportFrom(Map<String, Object?> row) {
    return MedicalReport(
      id: row['id'] as String,
      title: row['title'] as String? ?? 'Report',
      fileName: row['fileName'] as String? ?? 'report',
      mimeType: row['mimeType'] as String? ?? 'application/octet-stream',
      sizeBytes: (row['sizeBytes'] as num?)?.toInt() ?? 0,
      uploadedAt:
          DateTime.tryParse(row['uploadedAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      kind: MedicalRecordKind.from(row['kind']),
      addedBy: MedicalRecordAuthor.from(row['addedBy'] ?? row['uploadedBy']),
    );
  }

  @override
  Future<DateTime?> deleteAccount() async {
    final body = await _client.delete('/patients/me/account');

    return DateTime.tryParse(
      body['reinstateAfter'] as String? ?? '',
    )?.toLocal();
  }

  @override
  Future<String?> removePhoto() async {
    final body = await _client.delete('/patients/me/photo');
    return body['photo_url'] as String?;
  }

  PatientAccount _toAccount(Map<String, Object?> json) {
    final dateOfBirth = json['date_of_birth'] as String?;

    return PatientAccount(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: _formatPhone(json['phone'] as String?),
      dateOfBirth: dateOfBirth == null
          ? null
          : DateTime.tryParse(dateOfBirth)?.toLocal(),
      gender: Gender.fromKey(json['gender'] as String?),
      bloodGroup: BloodGroup.fromKey(json['blood_group'] as String?),
      // A path on the API — `/patients/me/photo` — not a public URL. See
      // `RemoteAvatar`, which is what turns it into an authenticated request.
      avatarUrl: json['photo_url'] as String?,
      medicalHistory: _toMedicalHistory(json['medical_history']),
    );
  }

  /// Null when the patient has never recorded anything, which the profile
  /// screen shows as an invitation rather than as four empty lists.
  static MedicalHistory? _toMedicalHistory(Object? value) {
    if (value is! Map<String, Object?>) return null;

    final updatedAt = value['updated_at'] as String?;

    return MedicalHistory(
      conditions: _stringsOf(value['conditions']),
      medications: _stringsOf(value['medications']),
      allergies: _stringsOf(value['allergies']),
      surgeries: _stringsOf(value['surgeries']),
      notes: value['notes'] as String?,
      lastUpdated: updatedAt == null
          ? null
          : DateTime.tryParse(updatedAt)?.toLocal(),
    );
  }

  static NotificationSettings _toSettings(Object? value) {
    if (value is! Map<String, Object?>) return const NotificationSettings();

    return NotificationSettings(
      // `!= false` rather than `== true`, so a field the server has not started
      // sending yet keeps its default rather than reading as switched off.
      consultationReminders: value['consultationReminders'] != false,
      chatMessages: value['chatMessages'] != false,
      promotions: value['promotions'] == true,
      emailUpdates: value['emailUpdates'] == true,
    );
  }

  static List<String> _stringsOf(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

  /// The part's own content type, read off the extension.
  ///
  /// Only the formats the store accepts for a photo. Anything else is left to
  /// the server to sniff and refuse, with a message the patient can act on.
  static String? _contentTypeOf(String path) {
    final extension = path.split('.').last.toLowerCase();

    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => null,
    };
  }

  /// `+919876543210` → `+91 98765 43210`. Falls back to the stored E.164 for
  /// countries whose grouping this does not know.
  static String _formatPhone(String? e164) {
    if (e164 == null || e164.isEmpty) return '—';
    if (!e164.startsWith('+91') || e164.length != 13) return e164;

    final digits = e164.substring(3);
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }
}
