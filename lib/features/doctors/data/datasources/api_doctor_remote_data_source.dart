import '../../../../core/network/api_client.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/doctor_review.dart';
import 'doctor_remote_data_source.dart';

/// The doctor directory, on the consultation API.
///
/// | Method | Path |
/// | ------ | ---- |
/// | GET    | /doctors?speciality=&availableNow=&limit= |
/// | GET    | /doctors/:id | one doctor in full
///
/// Only approved doctors come back — the API filters in the query rather than
/// after it, so an unreviewed registration cannot reach a patient by mistake.
class ApiDoctorRemoteDataSource implements DoctorRemoteDataSource {
  const ApiDoctorRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  Future<Doctor?> fetchDoctor(String id) async {
    final body = await _client.get('/doctors/${Uri.encodeComponent(id)}');

    final row = body['doctor'];
    if (row is! Map<String, Object?>) return null;

    return _doctorFrom(row);
  }

  @override
  Future<List<Doctor>> fetchDoctors({
    String? specialityId,
    bool availableNow = false,
  }) async {
    final query = <String>[
      'limit=50',
      if (specialityId != null)
        'speciality=${Uri.encodeQueryComponent(specialityId)}',
      // Only for the instant flow. Asking for a doctor *now* should not list
      // people who cannot answer, and the freshness window is the server's to
      // judge — a doctor whose app stopped checking in is not online however
      // their record reads.
      if (availableNow) 'availableNow=true',
    ];

    final body = await _client.get('/doctors?${query.join('&')}');

    return _doctorsFrom(body['doctors']);
  }

  static List<Doctor> _doctorsFrom(Object? value) {
    if (value is! List) return const [];

    return [
      for (final row in value.whereType<Map<String, Object?>>())
        if (row['id'] is String) _doctorFrom(row),
    ];
  }

  /// One row, list shape or profile shape.
  ///
  /// The same mapper for both, because the profile is the listing row with more
  /// fields on it rather than a different object. Everything past the fee is
  /// absent from a list response and simply reads as empty, which is what lets
  /// the detail screen render the row it was handed while the full profile
  /// loads behind it.
  static Doctor _doctorFrom(Map<String, Object?> row) {
    return Doctor(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Doctor',
      speciality: row['speciality'] as String? ?? 'General Physician',
      yearsOfExperience: (row['yearsOfExperience'] as num?)?.toInt() ?? 0,
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      consultationFee: (row['consultationFee'] as num?)?.toInt() ?? 0,
      audioConsultationFee: (row['audioConsultationFee'] as num?)?.toInt(),
      isVerified: row['isVerified'] == true,
      isAvailableNow: row['isAvailableNow'] == true,
      about: _textOf(row['about'] ?? row['bio']),
      qualifications: _stringsOf(row['qualifications'] ?? row['degrees']),
      languages: _stringsOf(row['languages']),
      consultationsDone: (row['consultationsDone'] as num?)?.toInt() ?? 0,
      reviewCount: (row['reviewCount'] as num?)?.toInt() ?? 0,
      photoUrl: row['photoUrl'] as String?,
      clinicName: _textOf(row['clinicName']),
      city: _textOf(row['city']),
      reviews: _reviewsFrom(row['reviews']),
      // Both spellings: the onboarding service files it as `registrationNumber`
      // and the doctor directory has returned `medicalRegistrationNumber`.
      registrationNumber: _textOf(
        row['registrationNumber'] ?? row['medicalRegistrationNumber'],
      ),
    );
  }

  /// Absent from a listing row, which reads as no reviews and is then filled in
  /// by the profile read that follows.
  static List<DoctorReview> _reviewsFrom(Object? value) {
    if (value is! List) return const [];

    return [
      for (final row in value.whereType<Map<String, Object?>>())
        if (row['id'] is String && _textOf(row['comment']) != null)
          DoctorReview(
            id: row['id'] as String,
            rating: (row['rating'] as num?)?.toInt() ?? 0,
            comment: _textOf(row['comment'])!,
            authorName: _textOf(row['authorName']) ?? 'Verified patient',
            mode: switch (row['mode']) {
              'audio' => ConsultationMode.audio,
              'video' => ConsultationMode.video,
              _ => null,
            },
            createdAt:
                DateTime.tryParse(
                  row['createdAt'] as String? ?? '',
                )?.toLocal() ??
                DateTime.now(),
          ),
    ];
  }

  /// Null for a missing value **and** for a blank one. A doctor whose bio is
  /// an empty string has no bio, and an About card containing nothing is worse
  /// than no About card.
  static String? _textOf(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  /// Tolerant of both shapes the API has used: a list, and a comma-separated
  /// string.
  static List<String> _stringsOf(Object? value) {
    if (value is List) {
      return [for (final entry in value) ?_textOf(entry)];
    }

    if (_textOf(value) case final text?) {
      return text
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }

    return const [];
  }
}
