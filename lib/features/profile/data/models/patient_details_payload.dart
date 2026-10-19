import '../../domain/entities/patient_details.dart';

/// Maps the editable details onto the `patients` columns.
extension PatientDetailsPayload on PatientDetails {
  Map<String, Object?> toPayload({DateTime? now}) {
    final trimmedEmail = email?.trim();
    final date = dateOfBirth;

    return {
      'full_name': fullName.trim(),
      // Empty clears the column rather than storing '', so `is null` checks
      // downstream stay meaningful.
      'email': (trimmedEmail?.isEmpty ?? true) ? null : trimmedEmail,
      // The column is `date`, not `timestamptz` — send the calendar day only.
      'date_of_birth': date == null
          ? null
          : '${date.year.toString().padLeft(4, '0')}-'
                '${date.month.toString().padLeft(2, '0')}-'
                '${date.day.toString().padLeft(2, '0')}',
      'gender': gender?.key,
      'blood_group': bloodGroup?.key,
      'updated_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }
}
