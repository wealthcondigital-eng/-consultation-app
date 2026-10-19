import '../../../../core/error/failure.dart';
import '../../domain/entities/consultation_mode.dart';
import '../../domain/entities/live_consultation.dart';
import '../../domain/repositories/consultation_session_repository.dart';
import '../datasources/consultation_session_remote_data_source.dart';

class ConsultationSessionRepositoryImpl
    implements ConsultationSessionRepository {
  const ConsultationSessionRepositoryImpl(this._remoteDataSource);

  final ConsultationSessionRemoteDataSource _remoteDataSource;

  @override
  Future<LiveConsultation> requestInstant({
    required ConsultationMode mode,
    String? speciality,
    bool isAnonymous = false,
    String? alias,
    String? concern,
  }) => _guard(
    () => _remoteDataSource.requestInstant(
      mode: mode,
      speciality: speciality,
      isAnonymous: isAnonymous,
      alias: alias,
      concern: concern,
    ),
  );

  @override
  Future<LiveConsultation> schedule({
    required String doctorId,
    required ConsultationMode mode,
    required DateTime scheduledAt,
    String? concern,
    bool isAnonymous = false,
    String? alias,
  }) => _guard(
    () => _remoteDataSource.schedule(
      doctorId: doctorId,
      mode: mode,
      scheduledAt: scheduledAt,
      concern: concern,
      isAnonymous: isAnonymous,
      alias: alias,
    ),
  );

  @override
  Stream<LiveConsultation> watch(String id) =>
      _remoteDataSource.watch(id).handleError(_asFailure);

  @override
  Stream<LiveConsultation?> watchIncoming() =>
      _remoteDataSource.watchIncoming().handleError(_asFailure);

  @override
  Future<LiveConsultation> cancel(String id) =>
      _guard(() => _remoteDataSource.cancel(id));

  @override
  Future<LiveConsultation> accept(String id) =>
      _guard(() => _remoteDataSource.accept(id));

  @override
  Future<LiveConsultation> decline(String id) =>
      _guard(() => _remoteDataSource.decline(id));

  @override
  Future<LiveConsultation> join(String id) =>
      _guard(() => _remoteDataSource.join(id));

  @override
  Future<LiveConsultation> end(String id) =>
      _guard(() => _remoteDataSource.end(id));

  @override
  Future<void> rate(
    String id, {
    required int rating,
    String? feedback,
    int? callQuality,
    List<String> tags = const [],
  }) => _guard(
    () => _remoteDataSource.rate(
      id,
      rating: rating,
      feedback: feedback,
      callQuality: callQuality,
      tags: tags,
    ),
  );

  /// Transport-level errors never reach the UI as-is.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }

  static Never _asFailure(Object error) {
    throw error is Failure ? error : const Failure.unexpected();
  }
}
