import 'dart:math';

import '../../domain/entities/code_name.dart';

/// Offers an alias for a patient consulting anonymously.
///
/// This interface used to have a second method, `startSession`, which opened
/// the "anonymous session" on a backend. It never did: the only implementation
/// was a stub that returned `anon-<timestamp>` and wrote nothing anywhere, so
/// the alias the patient chose reached no API and no doctor was ever rung.
///
/// There is no separate anonymous endpoint, and there should not be. An
/// anonymous consultation is an ordinary one whose patient is named by an
/// alias, and `POST /consultations/instant` already takes `isAnonymous` and
/// `alias` — so the booking now goes through the same matchmaking path as every
/// other instant consultation, and this is left with the one job that is really
/// its own.
abstract interface class AnonymousConsultRemoteDataSource {
  Future<CodeName> suggestCodeName();
}

/// Suggests an alias.
///
/// **Reference data the app owns**, like the speciality glyphs on the home feed:
/// the list is a handful of neutral words and the choice is a presentation
/// decision, so a round trip to fetch it would be a network call the patient
/// waits on for a text field's placeholder.
///
/// Uniqueness is not checked here and does not need to be. The alias is a
/// display name on one consultation, not an identity — two patients called
/// `Patient Otter` on different calls with different doctors is not a
/// collision, and making it unique across the service would mean keeping a
/// register of aliases, which is the one thing anonymity must not have.
class LocalAnonymousConsultRemoteDataSource
    implements AnonymousConsultRemoteDataSource {
  LocalAnonymousConsultRemoteDataSource();

  /// Neutral and non-identifying: animals carry no gender, age, region or
  /// religion, which is the whole point of the list.
  static const List<String> aliases = [
    'Hawk',
    'Falcon',
    'Otter',
    'Heron',
    'Ibex',
    'Lynx',
    'Marlin',
    'Osprey',
    'Sparrow',
    'Tern',
  ];

  final Random _random = Random();

  @override
  Future<CodeName> suggestCodeName() async {
    return CodeName('Patient ${aliases[_random.nextInt(aliases.length)]}');
  }
}
