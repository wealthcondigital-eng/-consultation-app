import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/otp_challenge.dart';
import '../../domain/entities/otp_code.dart';
import '../../domain/entities/phone_number.dart';
import '../../../onboarding/domain/entities/user_role.dart';
import '../../../startup/domain/entities/start_destination.dart';
import '../../../startup/domain/usecases/resolve_start_destination.dart';
import '../../domain/usecases/request_otp.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/verify_otp.dart';

enum OtpAction { none, verifying, resending }

/// Presentation state for the OTP screen: the code being typed, the resend
/// cooldown, and the three async actions.
class OtpVerificationController extends ChangeNotifier {
  OtpVerificationController(
    this._verifyOtp,
    this._requestOtp,
    this._resolveStartDestination,
    this._signOut,
  );

  final VerifyOtp _verifyOtp;

  /// Resending is the same call that started the session.
  final RequestOtp _requestOtp;

  final ResolveStartDestination _resolveStartDestination;

  /// Undoes a sign-in that turned out to belong to the other journey. The
  /// session is opened by the code being correct, which it was — it is the
  /// *app* this person asked for that is wrong, and leaving them signed in
  /// would put them one restart away from the side they were just refused.
  final SignOut _signOut;

  /// Where this person belongs now they are signed in.
  ///
  /// The same decision the app makes on a cold launch, so a doctor under
  /// review is never dropped into the patient flow by either path — and a
  /// number registered under the other role is turned away by both.
  Future<StartEntry> destinationAfterSignIn(UserRole? role) =>
      _resolveStartDestination.forSignedInUser(role: role);

  /// Ends a session that reached the wrong journey. Never throws: the user is
  /// going back to the landing screen either way, and a failed sign-out call
  /// still clears the local token.
  Future<void> abandonSession() async {
    try {
      await _signOut();
    } catch (_) {
      // Nothing to do and nothing to say — the landing screen is the next
      // thing they see regardless.
    }
  }

  late PhoneNumber _phoneNumber;
  PhoneNumber get phoneNumber => _phoneNumber;

  late String _verificationId;

  /// The cooldown the server asked for, rather than a constant.
  Duration _cooldown = OtpChallenge.defaultResendCooldown;

  Timer? _cooldownTimer;
  int _secondsRemaining = 0;

  OtpCode _code = const OtpCode.empty();
  OtpCode get code => _code;

  OtpAction _action = OtpAction.none;
  OtpAction get action => _action;

  bool get isBusy => _action != OtpAction.none;
  bool get isVerifying => _action == OtpAction.verifying;
  bool get isResending => _action == OtpAction.resending;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get canVerify => _code.isComplete && !isBusy;
  bool get canResend => _secondsRemaining == 0 && !isBusy;

  /// `00:28` — always two digits either side.
  String get resendCountdown {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Seeds the controller with the session the login screen started. Called
  /// once, from the screen's initState.
  void start({
    required PhoneNumber phoneNumber,
    required OtpChallenge challenge,
  }) {
    _phoneNumber = phoneNumber;
    _verificationId = challenge.verificationId;
    _cooldown = challenge.cooldown;
    _startCooldown();
  }

  void changeCode(String digits) {
    if (digits == _code.digits) return;

    _code = OtpCode(digits);
    _errorMessage = null;
    notifyListeners();
  }

  /// Returns true when the caller should move on to the app.
  Future<bool> verify({UserRole? role}) async {
    if (!_code.isComplete) return false;

    return _run(
      OtpAction.verifying,
      () => _verifyOtp(
        verificationId: _verificationId,
        code: _code,
        role: role?.name,
      ),
    );
  }

  /// Requests a fresh code and restarts the cooldown.
  Future<bool> resend() async {
    if (!canResend) return false;

    final succeeded = await _run(OtpAction.resending, () async {
      final challenge = await _requestOtp(_phoneNumber);
      _verificationId = challenge.verificationId;
      _cooldown = challenge.cooldown;
    });

    if (succeeded) {
      _code = const OtpCode.empty();
      _startCooldown();
    }
    return succeeded;
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _secondsRemaining = _cooldown.inSeconds;

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsRemaining--;
      if (_secondsRemaining <= 0) {
        _secondsRemaining = 0;
        timer.cancel();
      }
      notifyListeners();
    });

    notifyListeners();
  }

  Future<bool> _run(OtpAction action, Future<void> Function() task) async {
    if (isBusy) return false;

    _action = action;
    _errorMessage = null;
    notifyListeners();

    try {
      await task();
      return true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;

      // The gateway is throttling this number. Shutting the Resend button for
      // as long as it asked is the only useful thing the app can do: another
      // request would be refused, and a refused send still counts against the
      // window on most gateways — which is how a lockout outlives a reinstall.
      if (failure.isRateLimited) {
        _cooldown = failure.retryAfter ?? OtpChallenge.defaultResendCooldown;
        _startCooldown();
      }
      return false;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      return false;
    } finally {
      _action = OtpAction.none;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
