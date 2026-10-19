import 'package:consultation_app/features/home/data/datasources/home_remote_data_source.dart';
import 'package:consultation_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:consultation_app/features/home/domain/entities/home_feed.dart';
import 'package:consultation_app/features/home/domain/usecases/get_home_feed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Doctor', () {
    const doctor = Doctor(
      id: 'sunita-rao',
      name: 'Dr. Sunita Rao',
      speciality: 'Pediatrician',
      yearsOfExperience: 12,
      rating: 4.9,
      consultationFee: 600,
      isVerified: true,
    );

    test('formats its credentials line', () {
      expect(doctor.credentials, 'Pediatrician • 12 yrs exp');
    });

    test('always shows one decimal place of rating', () {
      expect(doctor.formattedRating, '4.9');
      expect(
        const Doctor(
          id: 'x',
          name: 'Dr. X',
          speciality: 'GP',
          yearsOfExperience: 3,
          rating: 5,
          consultationFee: 400,
        ).formattedRating,
        '5.0',
      );
    });
  });

  group('HomeFeed', () {
    test('greets by name when the profile is known', () {
      const feed = HomeFeed(
        patientFirstName: 'Rahul',
        specialities: [],
        doctors: [],
      );

      expect(feed.greeting, 'Hello, Rahul');
    });

    test('falls back to a generic greeting before the profile exists', () {
      expect(const HomeFeed.empty().greeting, 'Hello there');
    });
  });

  group('GetHomeFeed', () {
    test('returns specialities and doctors', () async {
      final feed = await GetHomeFeed(
        HomeRepositoryImpl(FakeHomeRemoteDataSource()),
      )();

      expect(feed.specialities, isNotEmpty);
      expect(feed.doctors, isNotEmpty);
      // The feed no longer carries the greeting name: it comes from the
      // patient's own record, which the controller overlays after this call.
      expect(feed.patientFirstName, isNull);
    });

    test('takes the greeting name from an overlay, not the feed', () {
      const feed = HomeFeed(
        patientFirstName: null,
        specialities: [],
        doctors: [],
      );

      expect(feed.greeting, 'Hello there');
      expect(feed.withPatientFirstName('Sagar').greeting, 'Hello, Sagar');
      // A blank record must not produce "Hello, ".
      expect(feed.withPatientFirstName(null).greeting, 'Hello there');
    });
  });
}
