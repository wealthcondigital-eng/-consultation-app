import '../entities/code_name.dart';
import '../repositories/anonymous_consult_repository.dart';

/// Pre-fills the booking form with an alias the patient can keep or replace.
class SuggestCodeName {
  const SuggestCodeName(this._repository);

  final AnonymousConsultRepository _repository;

  Future<CodeName> call() => _repository.suggestCodeName();
}
