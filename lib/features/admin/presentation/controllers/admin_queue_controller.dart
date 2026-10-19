import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/doctor_review.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/decide_doctor_application.dart';
import '../../domain/usecases/get_pending_doctors.dart';

/// Presentation state for the review queue.
class AdminQueueController extends ChangeNotifier {
  AdminQueueController(this._getPendingDoctors, this._decide, this._repository);

  final GetPendingDoctors _getPendingDoctors;
  final DecideDoctorApplication _decide;

  /// Only for the certificate link, which is a read rather than a decision.
  final AdminRepository _repository;

  List<DoctorReview> _pending = const [];
  List<DoctorReview> get pending => _pending;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get isInitialLoad => _isLoading && _pending.isEmpty;

  /// The doctor a decision is currently being sent for, so only that card
  /// shows a spinner rather than the whole list freezing.
  String? _decidingFor;
  String? get decidingFor => _decidingFor;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _pending = await _getPendingDoctors();
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approve(String doctorId) =>
      _decideThen(doctorId, () => _decide.approve(doctorId));

  Future<bool> reject(String doctorId, String reason) =>
      _decideThen(doctorId, () => _decide.reject(doctorId, reason));

  Future<String?> certificateUrl(String storagePath) async {
    try {
      return await _repository.certificateUrl(storagePath);
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> _decideThen(
    String doctorId,
    Future<void> Function() send,
  ) async {
    if (_decidingFor != null) return false;

    _decidingFor = doctorId;
    _errorMessage = null;
    notifyListeners();

    try {
      await send();

      // Dropped locally rather than refetching: the decision is made, and a
      // round trip would leave the card sitting there in the meantime.
      _pending = _pending
          .where((review) => review.doctorId != doctorId)
          .toList(growable: false);
      return true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      return false;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      return false;
    } finally {
      _decidingFor = null;
      notifyListeners();
    }
  }
}
