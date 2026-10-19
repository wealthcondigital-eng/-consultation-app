import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/consultation/domain/entities/matching_update.dart';
import 'package:consultation_app/features/consultation/domain/repositories/matchmaking_repository.dart';
import 'package:consultation_app/features/consultation/domain/usecases/find_doctor.dart';
import 'package:consultation_app/features/consultation/presentation/controllers/doctor_search_session.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:consultation_app/features/doctors/domain/entities/speciality.dart';
import 'package:consultation_app/features/doctors/domain/repositories/doctor_repository.dart';
import 'package:consultation_app/features/doctors/domain/usecases/get_doctors.dart';
import 'package:flutter_test/flutter_test.dart';

Doctor _doctor(String name) => Doctor(
  id: name,
  name: name,
  speciality: 'Cardiologist',
  yearsOfExperience: 12,
  rating: 4.8,
  consultationFee: 600,
  isAvailableNow: true,
);

/// Answers with whatever the test set up, and records what it was asked.
class _StubDoctorRepository implements DoctorRepository {
  _StubDoctorRepository({this.doctors = const [], this.failure});

  final List<Doctor> doctors;
  final Failure? failure;

  String? askedSpeciality;
  bool? askedAvailableNow;
  int calls = 0;

  @override
  Future<List<Doctor>> fetchDoctors({
    String? specialityId,
    bool availableNow = false,
  }) async {
    calls++;
    askedSpeciality = specialityId;
    askedAvailableNow = availableNow;

    if (failure case final failure?) throw failure;
    return doctors;
  }

  @override
  Future<Doctor?> fetchDoctor(String id) async => null;
}

class _StubMatchmakingRepository implements MatchmakingRepository {
  @override
  Stream<MatchingUpdate> findDoctor({
    required ConsultationMode mode,
    String? doctorId,
    bool isAnonymous = false,
    String? alias,
    String? concern,
  }) => const Stream.empty();

  /// The only thing the session uses this for is the countdown it shows.
  @override
  Future<Duration> estimatedWait() async => const Duration(seconds: 45);
}

DoctorSearchSession _session(_StubDoctorRepository doctors) {
  return DoctorSearchSession(
    GetDoctors(doctors),
    FindDoctor(_StubMatchmakingRepository()),
  );
}

/// Runs a search to completion, including the deliberate hold that keeps the
/// progress ring legible.
Future<void> _finish(DoctorSearchSession session) async {
  await Future<void>.delayed(
    DoctorSearchSession.settleDelay + const Duration(milliseconds: 50),
  );
}

void main() {
  // The session defers a notification out of the build phase, so it reads
  // `SchedulerBinding.instance` — which asserts unless a binding exists. These
  // are plain unit tests over a presentation controller, so the binding is
  // initialised rather than the production code being made to work without one.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DoctorSearchSession', () {
    test('starts idle, so the dashboard shows nothing', () {
      final session = _session(_StubDoctorRepository());
      addTearDown(session.dispose);

      expect(session.phase, DoctorSearchPhase.idle);
      expect(session.isActive, isFalse);
    });

    test('reports a search that is running', () async {
      final session = _session(
        _StubDoctorRepository(doctors: [_doctor('Dr. Rao')]),
      );
      addTearDown(session.dispose);

      final running = session.start();

      expect(session.isSearching, isTrue);
      expect(session.isActive, isTrue);
      expect(session.headline, 'Finding a doctor');

      await running;
      await _finish(session);
    });

    test('counts what it found, and offers it', () async {
      final session = _session(
        _StubDoctorRepository(
          doctors: [_doctor('Dr. Rao'), _doctor('Dr. Iyer')],
        ),
      );
      addTearDown(session.dispose);

      await session.start();
      await _finish(session);

      expect(session.phase, DoctorSearchPhase.found);
      expect(session.hasResults, isTrue);
      expect(session.headline, '2 doctors found');
      expect(session.results, hasLength(2));
    });

    test('says one doctor, not one doctors', () async {
      final session = _session(
        _StubDoctorRepository(doctors: [_doctor('Dr. Rao')]),
      );
      addTearDown(session.dispose);

      await session.start();
      await _finish(session);

      expect(session.headline, '1 doctor found');
    });

    test('an empty roster is an answer, not a failure', () async {
      final session = _session(_StubDoctorRepository());
      addTearDown(session.dispose);

      await session.start();
      await _finish(session);

      expect(session.phase, DoctorSearchPhase.empty);
      expect(session.hasResults, isFalse);
      expect(session.headline, 'No doctors available');
      // Still active: the card stays until the patient dismisses it, because a
      // search that quietly vanished is a search they would start again.
      expect(session.isActive, isTrue);
    });

    test('a failed search says what went wrong', () async {
      final session = _session(
        _StubDoctorRepository(failure: const Failure('No connection.')),
      );
      addTearDown(session.dispose);

      await session.start();

      expect(session.phase, DoctorSearchPhase.failed);
      expect(session.errorMessage, 'No connection.');
      expect(session.detail, 'No connection.');
    });

    test('asks only for doctors who can answer now', () async {
      final doctors = _StubDoctorRepository(doctors: [_doctor('Dr. Rao')]);
      final session = _session(doctors);
      addTearDown(session.dispose);

      const cardiology = Speciality(
        id: 'Cardiology',
        name: 'Cardiology',
        practitionerTitle: 'Cardiology',
        symbol: SpecialitySymbol.cardiology,
      );

      await session.start(speciality: cardiology, instantOnly: true);
      await _finish(session);

      // A listing that offers somebody who cannot take the call is the
      // difference between a list and a waiting room.
      expect(doctors.askedAvailableNow, isTrue);
      expect(doctors.askedSpeciality, 'Cardiology');
      // Carried so the card and the listing it opens agree about what was
      // asked for.
      expect(session.speciality, cardiology);
      expect(session.instantOnly, isTrue);
    });

    test('a second start while one is running is ignored', () async {
      final doctors = _StubDoctorRepository(doctors: [_doctor('Dr. Rao')]);
      final session = _session(doctors);
      addTearDown(session.dispose);

      final first = session.start();
      // A patient tapping Consult Now twice is asking for the same thing
      // twice. Two searches would leave the dashboard reporting whichever
      // finished last.
      await session.start();
      await first;
      await _finish(session);

      expect(doctors.calls, 1);
    });

    test('clearing takes the card off the dashboard', () async {
      final session = _session(
        _StubDoctorRepository(doctors: [_doctor('Dr. Rao')]),
      );
      addTearDown(session.dispose);

      await session.start();
      await _finish(session);
      expect(session.isActive, isTrue);

      session.clear();

      expect(session.phase, DoctorSearchPhase.idle);
      expect(session.isActive, isFalse);
      expect(session.results, isEmpty);
      expect(session.speciality, isNull);
    });

    test('a cleared search cannot put its answer back', () async {
      final session = _session(
        _StubDoctorRepository(doctors: [_doctor('Dr. Rao')]),
      );
      addTearDown(session.dispose);

      final running = session.start();
      // Dismissed while it was still in flight — the card is gone, and the
      // answer arriving afterwards must not bring it back.
      session.clear();

      await running;
      await _finish(session);

      expect(session.phase, DoctorSearchPhase.idle);
      expect(session.results, isEmpty);
    });
  });
}
