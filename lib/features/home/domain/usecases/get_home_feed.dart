import '../entities/home_feed.dart';
import '../repositories/home_repository.dart';

/// Loads the patient home screen's content.
class GetHomeFeed {
  const GetHomeFeed(this._repository);

  final HomeRepository _repository;

  Future<HomeFeed> call() => _repository.fetchHomeFeed();
}
