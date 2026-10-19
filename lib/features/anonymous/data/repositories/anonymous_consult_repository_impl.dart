import '../../../../core/error/failure.dart';
import '../../domain/entities/code_name.dart';
import '../../domain/repositories/anonymous_consult_repository.dart';
import '../datasources/anonymous_consult_remote_data_source.dart';

class AnonymousConsultRepositoryImpl implements AnonymousConsultRepository {
  const AnonymousConsultRepositoryImpl(this._remoteDataSource);

  final AnonymousConsultRemoteDataSource _remoteDataSource;

  @override
  Future<CodeName> suggestCodeName() async {
    try {
      return await _remoteDataSource.suggestCodeName();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }
}
