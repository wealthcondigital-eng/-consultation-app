import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../doctor_onboarding/domain/entities/bank_account.dart';
import '../../domain/entities/doctor_settings.dart';
import '../../domain/usecases/manage_doctor_practice.dart';

/// Presentation state for Bank & Payouts.
///
/// Two states, and the distinction matters: [summary] is what is on file, read
/// back **masked**, and [account] is the form. The form starts empty even when
/// an account exists, because the API never sends the number back in full —
/// changing where money goes means typing the whole destination again, which is
/// also the right amount of friction for the operation.
class BankAccountController extends ChangeNotifier {
  BankAccountController(this._manage);

  final ManageBankAccount _manage;

  BankAccountSummary _summary = const BankAccountSummary.none();
  BankAccountSummary get summary => _summary;

  BankAccount _account = const BankAccount();
  BankAccount get account => _account;

  /// True while the doctor is filling in a new destination. False shows the
  /// stored one with a button to replace it.
  bool _isEditing = false;
  bool get isEditing => _isEditing;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;

  /// True once the stored account has been read at least once.
  ///
  /// What lets the screen tell a failed read — nothing to show, so an error
  /// page — from a failed save, where the form is still full of what the doctor
  /// typed and losing it would be the worse outcome.
  bool get hasLoaded => _hasLoaded;

  bool get isInitialLoad => _isLoading && !_hasLoaded;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _showErrors = false;
  bool get showErrors => _showErrors;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get canSave => _account.isComplete && !_isSaving;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await _manage.load();
      // Straight into the form when there is nothing on file. A doctor who has
      // never given payout details did not come here to read an empty card.
      _isEditing = !_summary.isSet;
      _hasLoaded = true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Opens the form.
  ///
  /// The holder's name and the bank are seeded from what is on file — those two
  /// come back in full and re-typing them is pointless friction. The account
  /// number and the IFSC are not, because the number is masked and an IFSC
  /// belongs to the branch the number is at.
  void beginEditing() {
    if (_isEditing) return;

    _account = BankAccount(
      bankName: _summary.bankName ?? '',
      accountHolderName: _summary.accountHolderName ?? '',
      upiId: _summary.upiId ?? '',
    );
    _isEditing = true;
    _showErrors = false;
    notifyListeners();
  }

  void cancelEditing() {
    if (!_isEditing || !_summary.isSet) return;

    _account = const BankAccount();
    _isEditing = false;
    _showErrors = false;
    _errorMessage = null;
    notifyListeners();
  }

  void setBankName(String value) => _update(_account.copyWith(bankName: value));

  void setAccountHolderName(String value) =>
      _update(_account.copyWith(accountHolderName: value));

  void setAccountNumber(String value) =>
      _update(_account.copyWith(accountNumber: value));

  void setRoutingCode(String value) =>
      _update(_account.copyWith(routingCode: value));

  void setUpiId(String value) => _update(_account.copyWith(upiId: value));

  Future<bool> save() async {
    if (_isSaving) return false;

    if (!_account.isComplete) {
      _showErrors = true;
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await _manage.save(_account);
      // Cleared the moment it is stored. Nothing above the data layer should
      // keep holding a whole account number once it has been sent.
      _account = const BankAccount();
      _isEditing = false;
      return true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isSaving = false;
      notifyListeners();
    }

    return false;
  }

  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _update(BankAccount account) {
    _account = account;
    notifyListeners();
  }
}
