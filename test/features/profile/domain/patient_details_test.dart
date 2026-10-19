import 'package:consultation_app/features/profile/data/models/patient_details_payload.dart';
import 'package:consultation_app/features/profile/domain/entities/blood_group.dart';
import 'package:consultation_app/features/profile/domain/entities/gender.dart';
import 'package:consultation_app/features/profile/domain/entities/patient_details.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 8, 19);

PatientDetails _details({
  String fullName = 'Rahul Sharma',
  String? email = 'rahul@example.com',
  DateTime? dateOfBirth,
  Gender? gender = Gender.male,
  BloodGroup? bloodGroup = BloodGroup.oPositive,
}) {
  return PatientDetails(
    fullName: fullName,
    email: email,
    dateOfBirth: dateOfBirth,
    gender: gender,
    bloodGroup: bloodGroup,
  );
}

void main() {
  group('PatientDetails validation', () {
    test('requires a name of at least two characters', () {
      expect(_details(fullName: ' R ').hasValidName, isFalse);
      expect(_details(fullName: 'Jo').hasValidName, isTrue);
    });

    test('treats a missing email as valid, a malformed one as not', () {
      expect(_details(email: null).hasValidEmail, isTrue);
      expect(_details(email: '   ').hasValidEmail, isTrue);
      expect(_details(email: 'rahul@example').hasValidEmail, isFalse);
      expect(_details(email: 'rahul at example.com').hasValidEmail, isFalse);
      expect(_details(email: 'rahul@example.com').hasValidEmail, isTrue);
    });

    test('rejects a date of birth in the future or beyond a lifespan', () {
      expect(
        _details(dateOfBirth: DateTime(2027)).isValidDateOfBirth(_now),
        isFalse,
      );
      expect(
        _details(dateOfBirth: DateTime(1800)).isValidDateOfBirth(_now),
        isFalse,
      );
      expect(
        _details(dateOfBirth: DateTime(1991, 5, 18)).isValidDateOfBirth(_now),
        isTrue,
      );
      // Optional: never supplying one must not block a save.
      expect(_details().isValidDateOfBirth(_now), isTrue);
    });
  });

  group('PatientDetails payload', () {
    test('trims the name and formats the date as a calendar day', () {
      final payload = _details(
        fullName: '  Rahul Sharma  ',
        dateOfBirth: DateTime(1991, 5, 8),
      ).toPayload(now: _now);

      expect(payload['full_name'], 'Rahul Sharma');
      // The column is `date`, so no time component and zero-padded parts.
      expect(payload['date_of_birth'], '1991-05-08');
      expect(payload['gender'], 'male');
      expect(payload['blood_group'], 'o_positive');
    });

    test('clears an emptied email rather than storing a blank', () {
      expect(_details(email: '   ').toPayload()['email'], isNull);
      expect(_details(email: null).toPayload()['email'], isNull);
      expect(
        _details(email: ' rahul@example.com ').toPayload()['email'],
        'rahul@example.com',
      );
    });

    test('never writes the phone number or the consent stamps', () {
      // The number belongs to the verified session, and consent is a
      // record of something that happened. An edit form must not touch either.
      final payload = _details().toPayload();

      expect(payload.containsKey('phone'), isFalse);
      expect(payload.containsKey('id'), isFalse);
      expect(payload.containsKey('data_processing_consent_at'), isFalse);
      expect(payload.containsKey('terms_accepted_at'), isFalse);
    });
  });
}
