import 'package:consultation_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:consultation_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:consultation_app/features/profile/domain/entities/gender.dart';
import 'package:consultation_app/features/profile/domain/entities/patient_profile.dart';
import 'package:consultation_app/features/profile/domain/usecases/save_patient_profile.dart';
import 'package:consultation_app/features/profile/presentation/controllers/complete_profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed so the eighteenth birthday falls on a known day.
final _now = DateTime(2026, 9, 23);

DateTime _born(int years, {int dayOffset = 0}) =>
    DateTime(_now.year - years, _now.month, _now.day + dayOffset);

CompleteProfileController _controller() {
  final repository = ProfileRepositoryImpl(FakeProfileRemoteDataSource());
  return CompleteProfileController(
    SavePatientProfile(repository, clock: () => _now),
    clock: () => _now,
  );
}

/// Fills everything except the date of birth, which each test sets itself.
void _fill(CompleteProfileController controller, {DateTime? dateOfBirth}) {
  controller
    ..changeFullName('Rahul Sharma')
    ..changeGender(Gender.male)
    ..changeDataProcessingConsent(true)
    ..changeTermsAccepted(true);

  if (dateOfBirth != null) controller.changeDateOfBirth(dateOfBirth);
}

void main() {
  group('the age gate', () {
    test('saves an adult', () async {
      final controller = _controller();
      _fill(controller, dateOfBirth: _born(28));

      expect(await controller.submit(), CompleteProfileOutcome.saved);
    });

    test('admits someone on their eighteenth birthday', () async {
      final controller = _controller();
      _fill(controller, dateOfBirth: _born(PatientProfile.minAgeYears));

      expect(await controller.submit(), CompleteProfileOutcome.saved);
    });

    test('turns away someone one day short of eighteen', () async {
      final controller = _controller();
      _fill(
        controller,
        dateOfBirth: _born(PatientProfile.minAgeYears, dayOffset: 1),
      );

      expect(await controller.submit(), CompleteProfileOutcome.underage);
      expect(controller.age, PatientProfile.minAgeYears - 1);
    });

    test('reports the age so the dialog can name it', () async {
      final controller = _controller();
      _fill(controller, dateOfBirth: _born(14));

      expect(await controller.submit(), CompleteProfileOutcome.underage);
      expect(controller.age, 14);
    });

    test('leaves the date on the form so a typo can be corrected', () async {
      final controller = _controller();
      _fill(controller, dateOfBirth: _born(14));
      await controller.submit();

      // Nothing is cleared and nothing is locked — the user corrects the year
      // and carries straight on.
      expect(controller.dateOfBirth, isNotNull);

      controller.changeDateOfBirth(_born(41));
      expect(await controller.submit(), CompleteProfileOutcome.saved);
    });

    test('does not show the underage dialog for a half-filled form', () async {
      final controller = _controller();
      // A minor's date, but no name, gender or consent yet.
      controller.changeDateOfBirth(_born(14));

      expect(await controller.submit(), CompleteProfileOutcome.invalid);
    });

    test('a minor never reaches the field errors about their age', () async {
      final controller = _controller();
      _fill(controller, dateOfBirth: _born(14));
      await controller.submit();

      // The dialog says it; the field must not also go red, or the two
      // contradict each other.
      expect(controller.dateOfBirthError, isNull);
    });
  });

  group('the date field', () {
    test('asks for a date when none was picked', () async {
      final controller = _controller();
      _fill(controller);

      expect(await controller.submit(), CompleteProfileOutcome.invalid);
      expect(controller.dateOfBirthError, 'Select your date of birth.');
    });

    test('rejects a date in the future', () async {
      final controller = _controller();
      _fill(controller, dateOfBirth: _born(-2));

      expect(await controller.submit(), CompleteProfileOutcome.invalid);
      expect(controller.dateOfBirthError, 'Enter a real date of birth.');
    });

    test('stays quiet until the first submit', () {
      final controller = _controller();
      expect(controller.dateOfBirthError, isNull);
    });
  });
}
