import 'package:consultation_app/features/doctors/data/datasources/doctor_remote_data_source.dart';
import 'package:consultation_app/features/doctors/data/repositories/doctor_repository_impl.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor_list_filter.dart';
import 'package:consultation_app/features/doctors/domain/entities/speciality.dart';
import 'package:consultation_app/features/doctors/domain/usecases/get_doctors.dart';
import 'package:flutter_test/flutter_test.dart';

Doctor _doctor({
  String name = 'Dr. Amit Verma',
  String speciality = 'Senior Cardiologist',
  int fee = 800,
  bool availableNow = false,
}) {
  return Doctor(
    id: name,
    name: name,
    speciality: speciality,
    yearsOfExperience: 15,
    rating: 4.9,
    consultationFee: fee,
    isAvailableNow: availableNow,
  );
}

void main() {
  group('Doctor', () {
    test('formats its fee, experience and rating', () {
      final doctor = _doctor();

      expect(doctor.formattedFee, '₹800');
      expect(doctor.experienceLabel, '15 yrs Exp');
      expect(doctor.formattedRating, '4.9');
    });

    test('matches on name or speciality, case-insensitively', () {
      final doctor = _doctor();

      expect(doctor.matches('amit'), isTrue);
      expect(doctor.matches('CARDIO'), isTrue);
      expect(doctor.matches('  '), isTrue, reason: 'blank matches everything');
      expect(doctor.matches('dentist'), isFalse);
    });
  });

  group('Speciality', () {
    const cardiology = Speciality(
      id: 'cardiology',
      name: 'Cardio',
      practitionerTitle: 'Cardiologist',
      symbol: SpecialitySymbol.cardiology,
    );

    test('derives its listing heading and search hint', () {
      expect(cardiology.listingHeading, 'Cardiologists');
      expect(cardiology.searchHint, 'Search Cardiologist');
    });

    test(
      'one named by the backend keeps the name the directory filters on',
      () {
        // The id is the doctor record's `specialty` verbatim, because that is
        // what `GET /doctors?speciality=` matches. The app's own ids did not:
        // `cardiology` against a record reading `Cardiology`, so every tile led
        // to an empty list.
        final named = Speciality.named('Cardiology');

        expect(named.id, 'Cardiology');
        expect(named.name, 'Cardiology');
        expect(named.symbol, SpecialitySymbol.cardiology);
        // "Cardiology doctors", not "Cardiologys": a specialty name is not a
        // practitioner title and does not pluralise into one.
        expect(named.listingHeading, 'Cardiology doctors');
      },
    );

    test('falls back to a neutral glyph for a speciality it does not know', () {
      // A doctor's specialty is free text. A wrong icon is worse than a
      // generic one, so anything unrecognised draws the neutral mark.
      expect(
        Speciality.named('Nuclear Medicine').symbol,
        SpecialitySymbol.general,
      );
      expect(Speciality.named('Rheumatology').symbol, SpecialitySymbol.other);
      expect(
        Speciality.named('Pediatric Surgery').symbol,
        SpecialitySymbol.paediatrics,
      );
    });
  });

  group('DoctorListFilter', () {
    final doctors = [
      _doctor(name: 'Dr. Expensive', fee: 1000),
      _doctor(name: 'Dr. Available', fee: 800, availableNow: true),
      _doctor(name: 'Dr. Cheap', fee: 400),
    ];

    test('all keeps every doctor in the original order', () {
      final result = DoctorListFilter.all.apply(doctors);

      expect(result.map((d) => d.name), [
        'Dr. Expensive',
        'Dr. Available',
        'Dr. Cheap',
      ]);
    });

    test('availableNow keeps only doctors who can take a call', () {
      final result = DoctorListFilter.availableNow.apply(doctors);

      expect(result.map((d) => d.name), ['Dr. Available']);
    });

    test('feeLowToHigh sorts by fee without mutating the source', () {
      final result = DoctorListFilter.feeLowToHigh.apply(doctors);

      expect(result.map((d) => d.consultationFee), [400, 800, 1000]);
      expect(doctors.first.name, 'Dr. Expensive');
    });
  });

  group('GetDoctors', () {
    final useCase = GetDoctors(
      DoctorRepositoryImpl(const FakeDoctorRemoteDataSource()),
    );

    test('returns the doctors in a speciality', () async {
      final doctors = await useCase(specialityId: 'cardiology');

      expect(doctors, hasLength(2));
      expect(
        doctors.every((d) => d.speciality.contains('Cardiologist')),
        isTrue,
      );
    });

    test('returns every doctor when no speciality is given', () async {
      final all = await useCase();
      final cardiologists = await useCase(specialityId: 'cardiology');

      expect(all.length, greaterThan(cardiologists.length));
    });

    test('returns nothing for an unknown speciality', () async {
      expect(await useCase(specialityId: 'oncology'), isEmpty);
    });
  });
}
