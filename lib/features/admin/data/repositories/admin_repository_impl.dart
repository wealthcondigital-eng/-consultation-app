import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor_review.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_data_source.dart';

class AdminRepositoryImpl implements AdminRepository {
  const AdminRepositoryImpl(this._remoteDataSource);

  final AdminRemoteDataSource _remoteDataSource;

  @override
  Future<bool> isAdmin() => _guard(_remoteDataSource.isAdmin);

  @override
  Future<List<DoctorReview>> fetchPendingDoctors() =>
      _guard(_remoteDataSource.fetchPendingDoctors);

  @override
  Future<void> approve(String doctorId) =>
      _guard(() => _remoteDataSource.approve(doctorId));

  @override
  Future<void> reject(String doctorId, String reason) =>
      _guard(() => _remoteDataSource.reject(doctorId, reason));

  @override
  Future<String> certificateUrl(String storagePath) =>
      _guard(() => _remoteDataSource.certificateUrl(storagePath));

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
}
