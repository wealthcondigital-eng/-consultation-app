import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/features/doctor_onboarding/data/datasources/certificate_compressor.dart';
import 'package:consultation_app/features/doctor_onboarding/data/datasources/doctor_onboarding_remote_data_source.dart';
import 'package:consultation_app/features/doctor_onboarding/data/repositories/doctor_onboarding_repository_impl.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/bank_account.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/doctor_availability.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/doctor_credentials.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/doctor_setup_step.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/medical_certificate.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/entities/practice_setup.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/repositories/doctor_onboarding_repository.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/usecases/manage_availability.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/usecases/manage_practice_setup.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/usecases/parse_medical_certificate.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/usecases/submit_doctor_application.dart';
import 'package:consultation_app/features/doctor_onboarding/domain/usecases/watch_application_status.dart';
import 'package:flutter_test/flutter_test.dart';

const _certificate = MedicalCertificate(
  fileName: 'certificate.pdf',
  source: CertificateSource.gallery,
  sizeBytes: 1_482_000,
);

const _completeCredentials = DoctorCredentials(
  fullName: 'Dr. Sarah Jenkins',
  medicalDegree: 'MD - General Medicine',
  registrationNumber: 'REG-9920-A',
  specialty: 'Internal Medicine',
  state: 'New York',
  city: 'New York',
  yearsOfExperience: 8,
);

const _completeBank = BankAccount(
  bankName: 'Chase Bank',
  accountHolderName: 'Dr. Sarah Jenkins',
  accountNumber: '1234567890',
  routingCode: 'CHAS0123456',
);

DoctorOnboardingRepository _repository() =>
    DoctorOnboardingRepositoryImpl(FakeDoctorOnboardingRemoteDataSource());

void main() {
  group('DoctorSetupStep', () {
    test('walks forwards and back, stopping at the ends', () {
      expect(DoctorSetupStep.uploadVerify.number, 1);
      expect(DoctorSetupStep.uploadVerify.previous, isNull);
      expect(DoctorSetupStep.uploadVerify.next, DoctorSetupStep.details);
      expect(DoctorSetupStep.bank.next, isNull);
      expect(DoctorSetupStep.bank.previous, DoctorSetupStep.details);
    });
  });

  group('MedicalCertificate', () {
    test('accepts the formats the upload card advertises', () {
      for (final name in ['scan.pdf', 'photo.JPG', 'photo.jpeg', 'shot.png']) {
        final file = MedicalCertificate(
          fileName: name,
          source: CertificateSource.scan,
          sizeBytes: 1000,
        );
        expect(file.isAcceptable, isTrue, reason: name);
      }
    });

    test('turns away the wrong format and an oversized file', () {
      const wrongFormat = MedicalCertificate(
        fileName: 'notes.docx',
        source: CertificateSource.gallery,
        sizeBytes: 1000,
      );
      final tooBig = MedicalCertificate(
        fileName: 'scan.pdf',
        source: CertificateSource.scan,
        sizeBytes: MedicalCertificate.maxSizeBytes + 1,
      );

      expect(wrongFormat.rejectionReason, contains('PDF, JPG or PNG'));
      expect(tooBig.rejectionReason, contains('10MB'));
    });

    test('reads its size for display', () {
      expect(_certificate.sizeLabel, '1.4 MB');
      expect(
        const MedicalCertificate(
          fileName: 'a.png',
          source: CertificateSource.scan,
          sizeBytes: 2048,
        ).sizeLabel,
        '2 KB',
      );
    });

    test('names a content type the API allowlist accepts', () {
      // Regression. The upload sent no part content type at all, so every file
      // reached the API as `application/octet-stream`, which is not on its
      // allowlist — a real PDF came back as "Upload a PDF or a photo". It is
      // also the type the review console picks a viewer from, so an
      // octet-stream document has no viewer even once it is stored.
      const types = {
        'scan.pdf': 'application/pdf',
        'photo.JPG': 'image/jpeg',
        'photo.jpeg': 'image/jpeg',
        'shot.png': 'image/png',
      };

      types.forEach((name, expected) {
        final file = MedicalCertificate(
          fileName: name,
          source: CertificateSource.gallery,
          sizeBytes: 1000,
        );
        expect(file.mimeType, expected, reason: name);
      });
    });

    test('knows a photograph from a PDF, which is what gets compressed', () {
      expect(_certificate.isImage, isFalse);
      expect(
        const MedicalCertificate(
          fileName: 'scan.jpg',
          source: CertificateSource.scan,
          sizeBytes: 1000,
        ).isImage,
        isTrue,
      );
    });
  });

  group('ImageCertificateCompressor', () {
    test('leaves a PDF alone', () async {
      // Its images are already compressed inside the container, and taking one
      // apart needs a PDF engine rather than an image codec.
      expect(
        await const ImageCertificateCompressor().compress(_certificate),
        same(_certificate),
      );
    });

    test('hands back the original when there is no file on disk', () async {
      const noFile = MedicalCertificate(
        fileName: 'photo.jpg',
        source: CertificateSource.scan,
        sizeBytes: 1000,
      );

      expect(
        await const ImageCertificateCompressor().compress(noFile),
        same(noFile),
      );
    });
  });

  group('DoctorCredentials', () {
    test('lists what is still missing, in form order', () {
      const empty = DoctorCredentials();

      expect(empty.isComplete, isFalse);
      expect(empty.missingFields.first, DoctorCredentialField.fullName);
      expect(empty.missingFields.length, DoctorCredentialField.values.length);
      expect(_completeCredentials.isComplete, isTrue);
      expect(_completeCredentials.missingFields, isEmpty);
    });

    test('checks the registration number it will submit', () {
      DoctorCredentials withNumber(String number) =>
          DoctorCredentials(registrationNumber: number);

      expect(withNumber('').registrationNumberError, isNotNull);
      expect(withNumber('R-1').registrationNumberError, contains('too short'));
      expect(
        withNumber('REG 9920 A').registrationNumberError,
        contains('Letters, numbers'),
      );
      expect(withNumber('REG-9920-A').registrationNumberError, isNull);
    });

    test('marks only the fields the register confirmed', () {
      const parsed = DoctorCredentials(
        fullName: 'Dr. Sarah Jenkins',
        verifiedFields: {DoctorCredentialField.fullName},
      );

      expect(parsed.isAutoFilled, isTrue);
      expect(parsed.isVerified(DoctorCredentialField.fullName), isTrue);
      expect(parsed.isVerified(DoctorCredentialField.city), isFalse);
    });

    test('changing state clears the city that belonged to the old one', () {
      final moved = _completeCredentials.copyWith(
        state: 'California',
        clearCity: true,
      );

      expect(moved.state, 'California');
      expect(moved.city, isNull);
      expect(moved.isComplete, isFalse);
    });

    test('reads experience as years', () {
      expect(_completeCredentials.experienceLabel, '8 Years');
      expect(
        const DoctorCredentials(yearsOfExperience: 1).experienceLabel,
        '1 Year',
      );
    });
  });

  group('BankAccount', () {
    test('accepts a complete account', () {
      expect(_completeBank.isComplete, isTrue);
      expect(_completeBank.maskedAccountNumber, '•••• 7890');
    });

    test('checks the account number', () {
      BankAccount withNumber(String number) =>
          _completeBank.copyWith(accountNumber: number);

      expect(withNumber('').accountNumberError, isNotNull);
      expect(withNumber('12ab567890').accountNumberError, 'Digits only.');
      expect(withNumber('1234').accountNumberError, contains('9 to 18'));
      expect(withNumber('1' * 19).accountNumberError, contains('9 to 18'));
    });

    test('checks the routing code and the optional UPI ID', () {
      expect(
        _completeBank.copyWith(routingCode: '').routingCodeError,
        isNotNull,
      );
      expect(
        _completeBank.copyWith(routingCode: 'ABC').routingCodeError,
        contains('does not look right'),
      );
      // Optional: empty is fine, malformed is not.
      expect(_completeBank.upiIdError, isNull);
      expect(
        _completeBank.copyWith(upiId: 'not-a-upi').upiIdError,
        contains('name@bank'),
      );
      expect(
        _completeBank.copyWith(upiId: 'sarahjenkins@okaxis').upiIdError,
        isNull,
      );
    });
  });

  group('Availability', () {
    const nine = ClockTime(hour: 9, minute: 0);
    const ten = ClockTime(hour: 10, minute: 0);
    const halfPastNine = ClockTime(hour: 9, minute: 30);

    test('reads times in twelve-hour form', () {
      expect(nine.label, '9:00 AM');
      expect(nine.paddedLabel, '09:00 AM');
      expect(const ClockTime(hour: 13, minute: 5).label, '1:05 PM');
      expect(const ClockTime(hour: 0, minute: 0).label, '12:00 AM');
      expect(const ClockTime(hour: 12, minute: 0).label, '12:00 PM');
    });

    test('a slot knows its own shape and its neighbours', () {
      const morning = AvailabilitySlot(start: nine, end: ten);

      expect(morning.label, '9:00 AM - 10:00 AM');
      expect(morning.isValid, isTrue);
      expect(const AvailabilitySlot(start: ten, end: nine).isValid, isFalse);
      expect(
        morning.overlaps(const AvailabilitySlot(start: halfPastNine, end: ten)),
        isTrue,
      );
      expect(
        morning.overlaps(
          const AvailabilitySlot(
            start: ten,
            end: ClockTime(hour: 11, minute: 0),
          ),
        ),
        isFalse,
      );
    });

    test('a schedule needs a day and a window before it can be saved', () {
      const nothing = DoctorAvailability();
      const daysOnly = DoctorAvailability(days: {Weekday.monday});
      // Not const: a slot defines its own equality.
      final both = DoctorAvailability(
        days: const {Weekday.monday},
        slots: {const AvailabilitySlot(start: nine, end: ten)},
      );

      expect(nothing.validationError, contains('at least one day'));
      expect(daysOnly.validationError, contains('at least one time slot'));
      expect(both.isSaveable, isTrue);
      expect(both.slotCountLabel, '1 selected');
    });

    test('the presets are hourly windows the backend also knows', () {
      expect(AvailabilityPresets.hourly.first.label, '9:00 AM - 10:00 AM');
      expect(AvailabilityPresets.hourly.length, 8);
      expect(AvailabilityPresets.hourly.every((slot) => slot.isValid), isTrue);
    });

    test('going online with no hours is refused before the network', () {
      final manage = ManageAvailability(_repository());

      // A `Failure`, not an `ArgumentError`. The controller catches the first
      // for its message and everything else for the generic one, so an
      // `ArgumentError` reached the doctor as "Something went wrong" with the
      // reason it was carrying thrown away.
      expect(
        () => manage.save(const DoctorAvailability(isOnline: true)),
        throwsA(isA<Failure>()),
      );
    });

    test('clearing hours while offline is allowed', () {
      final manage = ManageAvailability(_repository());

      // The bug this closes: hours were required whatever the switch said, so
      // a doctor turning themselves off — which is what the switch is for —
      // found Save refused with no way to record it.
      expect(manage.save(const DoctorAvailability()), completes);
    });

    test(
      'the stored schedule comes back with its custom slots intact',
      () async {
        final manage = ManageAvailability(_repository());
        const custom = AvailabilitySlot(
          start: ClockTime(hour: 20, minute: 0),
          end: ClockTime(hour: 21, minute: 0),
        );

        await manage.save(
          DoctorAvailability(
            isOnline: false,
            days: const {Weekday.saturday},
            slots: {custom},
          ),
        );
        final loaded = await manage.load();

        expect(loaded.isOnline, isFalse);
        expect(loaded.days, {Weekday.saturday});
        expect(loaded.slots, {custom});
      },
    );
  });

  group('PracticeSetup', () {
    test('reads its progress', () {
      const setup = PracticeSetup(videoFee: 500, percentComplete: 60);

      expect(setup.progressLabel, '60% Completed');
      expect(setup.progress, closeTo(0.6, 0.001));
    });

    test('names both fees, and only what is set', () {
      // Two fees, not one. The screen used to collect a single amount and
      // write it to both, which priced a voice call the same as a video one.
      expect(
        const PracticeSetup(videoFee: 700, audioFee: 400).selectedFeeLabel,
        '₹700 video · ₹400 audio',
      );
      // Collapsed when they match: repeating the same number twice is noise.
      expect(
        const PracticeSetup(videoFee: 500, audioFee: 500).selectedFeeLabel,
        '₹500',
      );
      expect(const PracticeSetup(videoFee: 700).selectedFeeLabel, '₹700 video');
      expect(const PracticeSetup(audioFee: 400).selectedFeeLabel, '₹400 audio');
      expect(const PracticeSetup().selectedFeeLabel, '—');
    });

    test('offers fee options even before a read', () {
      // The options used to come from the backend, so a failed read left the
      // screen with no chips, no fee and a permanently disabled Continue.
      expect(const PracticeSetup().feeOptions, isNotEmpty);
    });

    test('each fee validates on its own, and null is not an error', () {
      const unset = PracticeSetup();
      for (final kind in ConsultationFeeKind.values) {
        expect(kind.errorFor(unset), isNull, reason: kind.name);
      }

      const tooLow = PracticeSetup(videoFee: 0);
      expect(ConsultationFeeKind.video.errorFor(tooLow), isNotNull);
      expect(ConsultationFeeKind.audio.errorFor(tooLow), isNull);

      const tooHigh = PracticeSetup(audioFee: 100001);
      expect(ConsultationFeeKind.audio.errorFor(tooHigh), isNotNull);
      expect(ConsultationFeeKind.video.errorFor(tooHigh), isNull);
    });

    test('a fee kind writes only its own field', () {
      const setup = PracticeSetup(videoFee: 700, audioFee: 400);

      final audioOnly = ConsultationFeeKind.audio.applyTo(setup, 450);
      expect(audioOnly.videoFee, 700);
      expect(audioOnly.audioFee, 450);

      final cleared = ConsultationFeeKind.audio.applyTo(setup, null);
      expect(cleared.videoFee, 700);
      expect(cleared.audioFee, isNull);
    });
  });

  group('ManagePracticeSetup', () {
    test('refuses both fees being unset, as a Failure', () {
      final manage = ManagePracticeSetup(
        DoctorOnboardingRepositoryImpl(FakeDoctorOnboardingRemoteDataSource()),
      );

      // A `Failure`, not an `ArgumentError`: the controller catches the first
      // for its message and everything else for the generic one, so an
      // `ArgumentError` reached the doctor as "Something went wrong" with the
      // real reason thrown away.
      expect(
        () => manage.saveFees(),
        throwsA(
          isA<Failure>().having(
            (failure) => failure.message,
            'message',
            contains('video or an audio'),
          ),
        ),
      );

      expect(() => manage.saveFees(videoFee: 0), throwsA(isA<Failure>()));
      expect(() => manage.saveFees(videoFee: 100001), throwsA(isA<Failure>()));
    });

    test('one fee at a time leaves the other alone', () async {
      final source = FakeDoctorOnboardingRemoteDataSource();
      final manage = ManagePracticeSetup(
        DoctorOnboardingRepositoryImpl(source),
      );

      await manage.saveFees(videoFee: 700, audioFee: 400);
      await manage.saveFees(audioFee: 450);

      final stored = await manage.load();
      expect(stored.videoFee, 700);
      expect(stored.audioFee, 450);
    });
  });

  group('ParseMedicalCertificate', () {
    test('fills the profile in from an acceptable file', () async {
      final parse = ParseMedicalCertificate(_repository());

      final credentials = await parse(_certificate);

      expect(credentials.fullName, 'Dr. Sarah Jenkins');
      expect(credentials.registrationNumber, 'REG-9920-A');
      expect(credentials.isComplete, isTrue);
      expect(
        credentials.isVerified(DoctorCredentialField.registrationNumber),
        isTrue,
      );
    });

    test('turns away a file the rules do not allow', () {
      final parse = ParseMedicalCertificate(_repository());

      expect(
        () => parse(
          const MedicalCertificate(
            fileName: 'notes.docx',
            source: CertificateSource.gallery,
            sizeBytes: 1000,
          ),
        ),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('SubmitDoctorApplication', () {
    test('files a complete registration for review', () async {
      final submit = SubmitDoctorApplication(_repository());

      final application = await submit(
        credentials: _completeCredentials,
        bankAccount: _completeBank,
        certificate: _certificate,
      );

      expect(application.id, isNotEmpty);
      expect(application.isUnderReview, isTrue);
      expect(application.submittedAt, isNotNull);
    });

    test('refuses an incomplete registration', () {
      final submit = SubmitDoctorApplication(_repository());

      // `Failure`, not `ArgumentError`. Controllers catch `Failure` for its
      // message and everything else for the generic one, so an `ArgumentError`
      // carrying a perfectly good explanation arrived as "Something went
      // wrong".
      expect(
        () => submit(
          credentials: const DoctorCredentials(),
          bankAccount: _completeBank,
          certificate: _certificate,
        ),
        throwsA(isA<Failure>()),
      );
      expect(
        () => submit(
          credentials: _completeCredentials,
          bankAccount: const BankAccount(),
          certificate: _certificate,
        ),
        throwsA(isA<Failure>()),
      );
    });

    test('refuses a certificate the upload would not accept', () {
      final submit = SubmitDoctorApplication(_repository());

      expect(
        () => submit(
          credentials: _completeCredentials,
          bankAccount: _completeBank,
          certificate: const MedicalCertificate(
            fileName: 'scan.docx',
            source: CertificateSource.gallery,
            sizeBytes: 1000,
          ),
        ),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('WatchApplicationStatus', () {
    test('reports the review, then the approval', () async {
      final watch = WatchApplicationStatus(_repository());

      final updates = await watch('application-1').toList();

      expect(updates.first.isUnderReview, isTrue);
      expect(updates.last.isApproved, isTrue);
    });
  });
}
