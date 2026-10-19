import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:consultation_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:consultation_app/features/auth/domain/entities/country.dart';
import 'package:consultation_app/features/auth/domain/entities/phone_number.dart';
import 'package:consultation_app/features/auth/domain/usecases/request_otp.dart';
import 'package:flutter_test/flutter_test.dart';

const _us = Country(
  isoCode: 'US',
  name: 'United States',
  dialCode: '+1',
  flag: 'US',
  digitGroups: [3, 3, 4],
);

void main() {
  group('PhoneNumber', () {
    test('groups digits per the country format', () {
      const phone = PhoneNumber(
        country: Country.india,
        nationalDigits: '9876543210',
      );

      expect(phone.formattedNational, '98765 43210');
      expect(phone.e164, '+919876543210');
    });

    test('formats a partially typed number', () {
      expect(PhoneNumber.formatDigits('987', Country.india), '987');
      expect(PhoneNumber.formatDigits('987654', Country.india), '98765 4');
    });

    test('honours a different grouping', () {
      const phone = PhoneNumber(country: _us, nationalDigits: '5551234567');

      expect(phone.formattedNational, '555 123 4567');
      expect(phone.e164, '+15551234567');
    });

    test('is only valid at the country digit count', () {
      const partial = PhoneNumber(
        country: Country.india,
        nationalDigits: '98765',
      );
      const complete = PhoneNumber(
        country: Country.india,
        nationalDigits: '9876543210',
      );

      expect(partial.isValid, isFalse);
      expect(complete.isValid, isTrue);
    });

    test('sample number matches the country format', () {
      expect(Country.india.sampleNumber, '98765 43210');
      expect(_us.sampleNumber, '987 654 3210');
    });
  });

  group('RequestOtp', () {
    final repository = AuthRepositoryImpl(const FakeAuthRemoteDataSource());

    test('rejects an incomplete number before hitting the network', () async {
      const incomplete = PhoneNumber(
        country: Country.india,
        nationalDigits: '98765',
      );

      expect(() => RequestOtp(repository)(incomplete), throwsA(isA<Failure>()));
    });

    test('returns a challenge for a complete number', () async {
      const phone = PhoneNumber(
        country: Country.india,
        nationalDigits: '9876543210',
      );

      final challenge = await RequestOtp(repository)(phone);

      expect(challenge.verificationId, isNotEmpty);
      // The server's cooldown travels with the id. It used to be a bare
      // string, and the wait was a constant compiled into the app — which is
      // what let the Resend button come back to life at the exact moment the
      // next request was certain to be refused.
      expect(challenge.cooldown, const Duration(seconds: 30));
    });
  });
}
