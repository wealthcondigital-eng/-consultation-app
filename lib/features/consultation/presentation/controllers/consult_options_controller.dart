import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/consult_option.dart';
import '../../domain/usecases/get_consult_options.dart';

/// Presentation state for the consult options screen.
class ConsultOptionsController extends ChangeNotifier {
  ConsultOptionsController(this._getConsultOptions);

  final GetConsultOptions _getConsultOptions;

  List<ConsultOption> _options = const [];
  List<ConsultOption> get options => _options;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// True while the first load runs, when there is nothing to show yet.
  bool get isInitialLoad => _isLoading && _options.isEmpty;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _options = await _getConsultOptions();
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
