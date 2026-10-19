import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/l10n/tr.dart';
import '../../domain/entities/country.dart';
import '../../domain/entities/otp_challenge.dart';
import '../../domain/entities/phone_number.dart';
import '../../domain/usecases/request_otp.dart';

/// Which async action, if any, is currently running.
enum PhoneLoginAction { none, requestingOtp }

/// Presentation state for the phone login screen.
class PhoneLoginController extends ChangeNotifier {
  PhoneLoginController(this._requestOtp);

  final RequestOtp _requestOtp;

  PhoneNumber _phoneNumber = const PhoneNumber(country: Country.india);
  PhoneNumber get phoneNumber => _phoneNumber;

  PhoneLoginAction _action = PhoneLoginAction.none;
  PhoneLoginAction get action => _action;

  bool get isBusy => _action != PhoneLoginAction.none;
  bool get isRequestingOtp => _action == PhoneLoginAction.requestingOtp;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// The challenge returned by the last successful OTP request.
  OtpChallenge? _challenge;
  OtpChallenge? get challenge => _challenge;

  /// When the next request to this number may be made.
  ///
  /// **Per number, not per install.** The server throttles the phone number, so
  /// reinstalling the app clears nothing — which is why "too many requests"
  /// survived a reinstall, and why this has to be checked before a request goes
  /// out rather than after one comes back refused. On most SMS gateways a
  /// refused send still counts against the window, so an app that keeps asking
  /// is an app that keeps the lockout alive.
  static final Map<String, DateTime> _nextAllowedRequest = {};

  bool get canSubmit => _phoneNumber.isValid && !isBusy;

  /// How long is left before this number may be texted again, or null when it
  /// may be texted now.
  Duration? get cooldownRemaining => _cooldownFor(_phoneNumber);

  static Duration? _cooldownFor(PhoneNumber phoneNumber) {
    final allowedAt = _nextAllowedRequest[phoneNumber.e164];
    if (allowedAt == null) return null;

    final remaining = allowedAt.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Forgets every cooldown.
  ///
  /// Called when the object graph is built, which is a fresh process in every
  /// case that matters: `main()` builds it once, and a test builds it per case
  /// and must not inherit a window from whichever test ran before it.
  static void resetCooldowns() => _nextAllowedRequest.clear();

  void changeDigits(String digits) {
    if (digits == _phoneNumber.nationalDigits) return;

    _phoneNumber = _phoneNumber.copyWith(nationalDigits: digits);
    _errorMessage = null;
    notifyListeners();
  }

  /// Requests an OTP. Returns true when the caller should navigate on.
  Future<bool> submit() async {
    if (isBusy) return false;

    // Refused here rather than by the server. A request the gateway is going to
    // turn down is worse than no request at all, and it is the only thing the
    // app can do about a lockout it did not cause.
    if (cooldownRemaining case final remaining?) {
      _errorMessage = tr(
        'A code was just sent to this number. Try again in {wait}.',
        {'wait': _spell(remaining)},
      );
      notifyListeners();
      return false;
    }

    return _run(PhoneLoginAction.requestingOtp, () async {
      final challenge = await _requestOtp(_phoneNumber);
      _challenge = challenge;
      _nextAllowedRequest[_phoneNumber.e164] = DateTime.now().add(
        challenge.cooldown,
      );
    });
  }

  Future<bool> _run(
    PhoneLoginAction action,
    Future<void> Function() task,
  ) async {
    if (isBusy) return false;

    _action = action;
    _errorMessage = null;
    notifyListeners();

    try {
      await task();
      return true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;

      // The server said to back off, so the next attempt is held even though
      // this one never produced a challenge to take a cooldown from.
      if (failure.isRateLimited) {
        _nextAllowedRequest[_phoneNumber.e164] = DateTime.now().add(
          failure.retryAfter ?? OtpChallenge.defaultResendCooldown,
        );
      }
      return false;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      return false;
    } finally {
      _action = PhoneLoginAction.none;
      notifyListeners();
    }
  }

  /// `45 seconds` / `2 minutes` — a wait a person can act on, rather than
  /// `0:00:45.000000`.
  static String _spell(Duration remaining) {
    final seconds = remaining.inSeconds + 1;
    if (seconds < 60) {
      return seconds == 1
          ? tr('1 second')
          : tr('{count} seconds', {'count': seconds});
    }

    final minutes = (seconds / 60).ceil();
    return minutes == 1
        ? tr('1 minute')
        : tr('{count} minutes', {'count': minutes});
  }
}
