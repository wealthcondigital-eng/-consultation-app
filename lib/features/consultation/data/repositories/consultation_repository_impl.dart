import '../../../../core/error/failure.dart';
import '../../domain/entities/consult_option.dart';
import '../../domain/repositories/consultation_repository.dart';
import '../datasources/consultation_remote_data_source.dart';

class ConsultationRepositoryImpl implements ConsultationRepository {
  const ConsultationRepositoryImpl(this._remoteDataSource);

  final ConsultationRemoteDataSource _remoteDataSource;

  @override
  Future<List<ConsultOption>> fetchConsultOptions() async {
    try {
      return await _remoteDataSource.fetchConsultOptions();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }
}
