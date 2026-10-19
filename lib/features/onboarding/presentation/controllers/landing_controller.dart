import 'package:flutter/foundation.dart';

import '../../domain/entities/user_role.dart';
import '../../domain/usecases/select_role.dart';

/// Presentation state for the landing screen.
///
/// Kept as a plain [ChangeNotifier] so the app carries no state-management
/// dependency; it exposes the same shape a Bloc/Riverpod notifier would, so
/// moving to one later is contained to this file and its listener.
class LandingController extends ChangeNotifier {
  LandingController(this._selectRole);

  final SelectRole _selectRole;

  UserRole? _pendingRole;

  /// The role currently being submitted, if any — drives the button spinner.
  UserRole? get pendingRole => _pendingRole;

  bool get isBusy => _pendingRole != null;

  bool isPending(UserRole role) => _pendingRole == role;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Persists the choice and reports whether the caller should navigate on.
  Future<bool> chooseRole(UserRole role) async {
    if (isBusy) return false;

    _pendingRole = role;
    _errorMessage = null;
    notifyListeners();

    try {
      await _selectRole(role);
      return true;
    } catch (error) {
      _errorMessage = 'Could not continue. Please try again.';
      return false;
    } finally {
      _pendingRole = null;
      notifyListeners();
    }
  }
}
