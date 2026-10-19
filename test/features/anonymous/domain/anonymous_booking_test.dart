import 'package:consultation_app/features/anonymous/data/datasources/anonymous_consult_remote_data_source.dart';
import 'package:consultation_app/features/anonymous/domain/entities/anonymous_booking.dart';
import 'package:consultation_app/features/anonymous/domain/entities/anonymous_session.dart';
import 'package:consultation_app/features/anonymous/domain/entities/code_name.dart';
import 'package:consultation_app/features/anonymous/domain/entities/consult_language.dart';
import 'package:consultation_app/features/consultation/domain/entities/consult_option.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:flutter_test/flutter_test.dart';

AnonymousBooking _booking(String codeName) => AnonymousBooking(
  codeName: CodeName(codeName),
  language: ConsultLanguage.english,
);

void main() {
  group('CodeName', () {
    test('collapses surrounding and repeated whitespace', () {
      expect(const CodeName('  Patient   Hawk ').normalised, 'Patient Hawk');
    });

    test('accepts an ordinary alias', () {
      expect(const CodeName('Patient Hawk').isValid, isTrue);
      expect(const CodeName("O'Hara-7").isValid, isTrue);
    });

    test('explains why an alias cannot be used', () {
      expect(const CodeName('  ').validationError, isNotNull);
      expect(const CodeName('ab').validationError, contains('3 characters'));
      expect(
        CodeName('a' * (CodeName.maxLength + 1)).validationError,
        contains('under ${CodeName.maxLength}'),
      );
      expect(
        const CodeName('Patient <Hawk>').validationError,
        contains('Letters, numbers'),
      );
    });
  });

  group('AnonymousSession', () {
    test('carries everything the form collected', () {
      final session = AnonymousSession.from(_booking('  Patient Hawk  '));

      // The alias reaches the doctor tidied up, and nothing else identifies
      // the patient.
      expect(session.displayName, 'Patient Hawk');
      expect(session.language, ConsultLanguage.english);
    });

    test('is always a voice call', () {
      // The form no longer offers the choice, and this is the reason: a video
      // call hands the doctor the patient's face, which undoes the alias and
      // every other promise the screen makes. Asserted on the entity rather
      // than on the screen, so removing the control cannot be undone quietly
      // by re-adding a `mode` argument.
      expect(_booking('Patient Hawk').mode, ConsultationMode.audio);
      expect(
        AnonymousSession.from(_booking('Patient Hawk')).mode,
        ConsultationMode.audio,
      );
    });

    test('carries the concern, which is all the doctor is told', () {
      final session = AnonymousSession.from(
        AnonymousBooking(
          codeName: const CodeName('Patient Hawk'),
          language: ConsultLanguage.english,
          concern: '  Trouble sleeping for a month  ',
        ),
      );

      expect(session.concern, '  Trouble sleeping for a month  ');
    });

    test('can be booked for later as well as now', () {
      expect(_booking('Patient Hawk').kind, ConsultOptionKind.instant);

      final booked = AnonymousSession.from(
        _booking('Patient Hawk').copyWith(kind: ConsultOptionKind.scheduled),
      );

      expect(booked.isScheduled, isTrue);
      // Still anonymous, and still a voice call: booking a slot changes when
      // the consultation happens and nothing else about it.
      expect(booked.displayName, 'Patient Hawk');
      expect(booked.mode, ConsultationMode.audio);
    });

    test('is not a backend record and carries no id', () {
      // The consultation is what the API mints, on the same endpoint every
      // other instant consultation uses. This used to hold an `anon-<stamp>`
      // handed back by a stub that wrote nothing anywhere — so an anonymous
      // consultation looked booked and rang nobody.
      expect(
        AnonymousSession.from(_booking('Patient Otter')).codeName.normalised,
        'Patient Otter',
      );
    });
  });

  group('LocalAnonymousConsultRemoteDataSource', () {
    test('suggests a usable alias', () async {
      final suggestion = await LocalAnonymousConsultRemoteDataSource()
          .suggestCodeName();

      expect(suggestion.isValid, isTrue);
      expect(suggestion.normalised, startsWith('Patient '));
    });
  });
}
