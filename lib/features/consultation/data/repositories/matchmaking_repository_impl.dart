import '../../../../core/error/failure.dart';
import '../../domain/entities/consultation_mode.dart';
import '../../domain/entities/matching_update.dart';
import '../../domain/repositories/matchmaking_repository.dart';
import '../datasources/matchmaking_remote_data_source.dart';

class MatchmakingRepositoryImpl implements MatchmakingRepository {
  const MatchmakingRepositoryImpl(this._remoteDataSource);

  final MatchmakingRemoteDataSource _remoteDataSource;

  @override
  Stream<MatchingUpdate> findDoctor({
    required ConsultationMode mode,
    String? doctorId,
    bool isAnonymous = false,
    String? alias,
    String? concern,
  }) {
    return _remoteDataSource
        .findDoctor(
          mode: mode,
          doctorId: doctorId,
          isAnonymous: isAnonymous,
          alias: alias,
          concern: concern,
        )
        .handleError((Object error) {
          // Anything the transport throws reaches the UI as a Failure.
          throw error is Failure ? error : const Failure.unexpected();
        });
  }

  @override
  Future<Duration> estimatedWait() async {
    try {
      return await _remoteDataSource.estimatedWait();
    } catch (_) {
      // A missing estimate must not stop the search.
      return const Duration(seconds: 60);
    }
  }
}
