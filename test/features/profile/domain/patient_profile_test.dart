import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:consultation_app/features/profile/data/models/patient_profile_payload.dart';
import 'package:consultation_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:consultation_app/features/profile/domain/entities/gender.dart';
import 'package:consultation_app/features/profile/domain/entities/patient_profile.dart';
import 'package:consultation_app/features/profile/domain/usecases/save_patient_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed so the age boundaries are the same every run.
final _now = DateTime(2026, 9, 23);

/// A date of birth that makes someone exactly [years] old on [_now].
DateTime _born(int years, {int dayOffset = 0}) =>
    DateTime(_now.year - years, _now.month, _now.day + dayOffset);

PatientProfile _profile({
  String fullName = 'Rahul Sharma',
  DateTime? dateOfBirth,
  bool noDateOfBirth = false,
  Gender? gender = Gender.male,
  bool dataProcessingConsent = true,
  bool termsAccepted = true,
}) {
  return PatientProfile(
    fullName: fullName,
    dateOfBirth: noDateOfBirth ? null : dateOfBirth ?? _born(28),
    gender: gender,
    dataProcessingConsent: dataProcessingConsent,
    termsAccepted: termsAccepted,
  );
}

void main() {
  group('PatientProfile', () {
    test('is complete when every field is filled and both consents given', () {
      expect(_profile().isComplete(_now), isTrue);
    });

    test('rejects a name that is too short, whitespace included', () {
      expect(_profile(fullName: 'R').hasValidName, isFalse);
      expect(_profile(fullName: '   ').hasValidName, isFalse);
      expect(_profile(fullName: ' Jo ').hasValidName, isTrue);
    });

    test('counts age in whole years, and only after the birthday', () {
      expect(_profile(dateOfBirth: _born(28)).ageAt(_now), 28);

      // Born tomorrow's date, 28 years ago: the birthday has not happened yet.
      expect(_profile(dateOfBirth: _born(28, dayOffset: 1)).ageAt(_now), 27);
    });

    test('rejects a missing, future or impossible date of birth', () {
      expect(
        _profile(noDateOfBirth: true).isDateOfBirthPlausible(_now),
        isFalse,
      );
      expect(
        _profile(dateOfBirth: _born(-1)).isDateOfBirthPlausible(_now),
        isFalse,
      );
      expect(
        _profile(
          dateOfBirth: _born(PatientProfile.maxAgeYears + 1),
        ).isDateOfBirthPlausible(_now),
        isFalse,
      );
      expect(
        _profile(
          dateOfBirth: _born(PatientProfile.maxAgeYears),
        ).isDateOfBirthPlausible(_now),
        isTrue,
      );
    });

    test('admits 18 and turns away anyone younger', () {
      expect(
        _profile(
          dateOfBirth: _born(PatientProfile.minAgeYears),
        ).isOldEnough(_now),
        isTrue,
      );

      // One day short of the eighteenth birthday.
      expect(
        _profile(
          dateOfBirth: _born(PatientProfile.minAgeYears, dayOffset: 1),
        ).isOldEnough(_now),
        isFalse,
      );
      expect(_profile(dateOfBirth: _born(12)).isOldEnough(_now), isFalse);
    });

    test('a minor is incomplete however well the rest is filled in', () {
      expect(_profile(dateOfBirth: _born(15)).isComplete(_now), isFalse);
    });

    test('is incomplete without a gender', () {
      expect(_profile(gender: null).isComplete(_now), isFalse);
    });

    test('is incomplete without either consent', () {
      expect(_profile(dataProcessingConsent: false).isComplete(_now), isFalse);
      expect(_profile(termsAccepted: false).isComplete(_now), isFalse);
    });
  });

  group('payload', () {
    test('trims the name and uses the persistence keys', () {
      final stamp = DateTime.utc(2026, 8, 18, 9, 30);
      final payload = _profile(
        fullName: '  Rahul Sharma  ',
        dateOfBirth: DateTime(1998, 3, 7),
      ).toPayload(now: stamp);

      expect(payload['full_name'], 'Rahul Sharma');
      expect(payload['gender'], 'male');

      // The calendar day only — the column is `date`, not `timestamptz`.
      expect(payload['date_of_birth'], '1998-03-07');

      // Consent is stamped, not flagged — the DPDP Act wants the moment it was
      // given, and the column is `timestamptz not null`.
      expect(payload['data_processing_consent_at'], stamp.toIso8601String());
      expect(payload['terms_accepted_at'], stamp.toIso8601String());
    });

    test('zero-pads a single-digit month and day', () {
      final payload = _profile(
        dateOfBirth: DateTime(2001, 1, 9),
      ).toPayload(now: DateTime.utc(2026, 8, 18));

      expect(payload['date_of_birth'], '2001-01-09');
    });

    test('leaves a withheld consent unstamped', () {
      final payload = _profile(termsAccepted: false).toPayload();

      expect(payload['data_processing_consent_at'], isNotNull);
      expect(payload['terms_accepted_at'], isNull);
    });
  });

  group('SavePatientProfile', () {
    final repository = ProfileRepositoryImpl(FakeProfileRemoteDataSource());
    SavePatientProfile save() =>
        SavePatientProfile(repository, clock: () => _now);

    test('refuses an incomplete profile even if the UI let it through', () {
      expect(
        () => save()(_profile(dataProcessingConsent: false)),
        throwsA(isA<Failure>()),
      );
    });

    test('refuses a minor even if the UI let it through', () {
      expect(
        () => save()(_profile(dateOfBirth: _born(15))),
        throwsA(isA<Failure>()),
      );
    });

    test('saves a complete profile', () async {
      await expectLater(save()(_profile()), completes);
    });
  });
}
