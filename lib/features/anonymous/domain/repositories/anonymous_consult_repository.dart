import '../entities/code_name.dart';

/// Contract for consulting without revealing who you are.
///
/// One method. `startSession` used to live here too; the consultation itself is
/// filed through `ConsultationSessionRepository` like every other instant
/// consultation now, with `isAnonymous` and the alias attached — see
/// [AnonymousSession] for why there was never a separate record to open.
abstract interface class AnonymousConsultRepository {
  /// An alias to offer the patient, e.g. `Patient Hawk`.
  Future<CodeName> suggestCodeName();
}
