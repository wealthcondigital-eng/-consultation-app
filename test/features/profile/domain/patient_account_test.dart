import 'package:consultation_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:consultation_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:consultation_app/features/profile/domain/entities/blood_group.dart';
import 'package:consultation_app/features/profile/domain/entities/gender.dart';
import 'package:consultation_app/features/profile/domain/entities/medical_history.dart';
import 'package:consultation_app/features/profile/domain/entities/patient_account.dart';
import 'package:consultation_app/features/profile/domain/usecases/get_patient_account.dart';
import 'package:flutter_test/flutter_test.dart';

PatientAccount _account({
  String fullName = 'Alexander Wright',
  DateTime? dateOfBirth,
}) {
  return PatientAccount(
    id: 'patient-1',
    fullName: fullName,
    email: 'alexander.wright@gmail.com',
    phoneNumber: '+1 (555) 234-5678',
    dateOfBirth: dateOfBirth,
  );
}

void main() {
  group('PatientAccount', () {
    test('takes its initials from the first and last name', () {
      expect(_account().initials, 'AW');
      expect(_account(fullName: 'Prince').initials, 'P');
      expect(_account(fullName: '  ada   lovelace  ').initials, 'AL');
      expect(_account(fullName: '   ').initials, '?');
    });

    test('takes the greeting name from the first word', () {
      expect(_account().firstName, 'Alexander');
      expect(_account(fullName: 'Prince').firstName, 'Prince');
      expect(_account(fullName: '  ada   lovelace  ').firstName, 'ada');
      // Blank, so the dashboard greets generically instead of "Hello, ".
      expect(_account(fullName: '   ').firstName, isNull);
    });

    test('spells the date of birth out, or shows a dash without one', () {
      expect(
        _account(dateOfBirth: DateTime(1991, 5, 18)).dateOfBirthLabel,
        'May 18, 1991',
      );
      expect(_account().dateOfBirthLabel, '—');
    });

    test('counts age in whole years', () {
      final account = _account(dateOfBirth: DateTime(1991, 5, 18));

      // The day before the birthday, and the day itself.
      expect(account.ageAt(DateTime(2026, 5, 17)), 34);
      expect(account.ageAt(DateTime(2026, 5, 18)), 35);
      expect(_account().ageAt(DateTime(2026, 5, 18)), isNull);
    });
  });

  group('MedicalHistory', () {
    test('reads a list of conditions as a phrase', () {
      DateTime updated() => DateTime(2024, 10, 12);

      expect(
        MedicalHistory(
          conditions: const ['Asthma', 'Seasonal Allergies'],
          lastUpdated: updated(),
        ).conditionsLabel,
        'Asthma & Seasonal Allergies',
      );
      expect(
        MedicalHistory(
          conditions: const ['Asthma', 'Eczema', 'Seasonal Allergies'],
          lastUpdated: updated(),
        ).conditionsLabel,
        'Asthma, Eczema & Seasonal Allergies',
      );
      expect(
        MedicalHistory(
          conditions: const ['Asthma'],
          lastUpdated: updated(),
        ).conditionsLabel,
        'Asthma',
      );
      expect(
        MedicalHistory(
          conditions: const [],
          lastUpdated: updated(),
        ).conditionsLabel,
        'No recorded conditions',
      );
    });

    test('summarises when it was updated and what is prescribed', () {
      final history = MedicalHistory(
        conditions: const ['Asthma'],
        lastUpdated: DateTime(2024, 10, 12),
        medications: const ['Albuterol Inhaler'],
      );

      expect(
        history.summary,
        'Last updated Oct 12, 2024. Active prescriptions include '
        'Albuterol Inhaler.',
      );
    });

    test('names what the patient is allergic to', () {
      final history = MedicalHistory(
        conditions: const ['Asthma'],
        lastUpdated: DateTime(2024, 10, 12),
        allergies: const ['Penicillin'],
      );

      expect(
        history.summary,
        'Last updated Oct 12, 2024. Allergic to Penicillin.',
      );
    });

    test('drops the prescription sentence when there is none', () {
      final history = MedicalHistory(
        conditions: const ['Asthma'],
        lastUpdated: DateTime(2024, 10, 12),
      );

      expect(history.summary, 'Last updated Oct 12, 2024.');
    });

    test('says so rather than quoting a date it does not have', () {
      expect(const MedicalHistory.empty().summary, 'Not recorded yet.');
      expect(const MedicalHistory.empty().isEmpty, isTrue);
    });

    test('counts only the sections that have something in them', () {
      const history = MedicalHistory(
        conditions: ['Asthma'],
        allergies: ['Penicillin'],
      );

      expect(history.filledSections, 2);
      expect(history.isNotEmpty, isTrue);
    });

    test('sends null rather than an empty note', () {
      const payload = MedicalHistory(conditions: ['Asthma'], notes: '   ');

      expect(payload.toPayload()['notes'], isNull);
      expect(payload.toPayload()['conditions'], ['Asthma']);
    });
  });

  group('BloodGroup', () {
    test('spells itself out and round-trips its key', () {
      expect(BloodGroup.oPositive.label, 'O Positive (O+)');
      expect(BloodGroup.oPositive.shortLabel, 'O+');
      expect(BloodGroup.fromKey('o_positive'), BloodGroup.oPositive);
      expect(BloodGroup.fromKey('unknown'), isNull);
    });
  });

  group('GetPatientAccount', () {
    test('returns the stored account', () async {
      final getAccount = GetPatientAccount(
        ProfileRepositoryImpl(FakeProfileRemoteDataSource()),
      );

      final account = await getAccount();

      expect(account.fullName, 'Alexander Wright');
      expect(account.gender, Gender.male);
      expect(account.bloodGroup, BloodGroup.oPositive);
      expect(account.medicalHistory?.medications, isNotEmpty);
    });
  });
}
