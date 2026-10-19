import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_auth/smart_auth.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../onboarding/domain/entities/user_role.dart';
import '../../../startup/domain/entities/start_destination.dart';
import '../../domain/entities/otp_challenge.dart';
import '../../domain/entities/otp_code.dart';
import '../../domain/entities/phone_number.dart';
import '../controllers/otp_verification_controller.dart';
import '../widgets/otp_input.dart';
import '../widgets/resend_countdown.dart';

/// Everything the OTP screen needs to resume the session the login screen
/// started. Passed as the route's arguments.
class OtpVerificationArgs {
  const OtpVerificationArgs({
    required this.phoneNumber,
    required this.challenge,
    this.role,
  });

  final PhoneNumber phoneNumber;

  /// The verification id **and** the cooldown the server asked for. It used to
  /// be the id alone, with the wait hard-coded at thirty seconds — see
  /// [OtpChallenge] for why that is what kept "too many requests" alive.
  final OtpChallenge challenge;

  final UserRole? role;
}

/// Step two of the OTP login: confirm the code we texted.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.args});

  final OtpVerificationArgs args;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  late final OtpVerificationController _controller =
      sl<OtpVerificationController>();
  final TextEditingController _codeTextController = TextEditingController();
  bool _hasAutoVerified = false;

  @override
  void initState() {
    super.initState();
    _controller.start(
      phoneNumber: widget.args.phoneNumber,
      challenge: widget.args.challenge,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFillOtp();
    });
    _listenForSms();
  }

  static bool get _canReadSms =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Reads the code out of the incoming SMS on Android.
  ///
  /// The SMS User Consent API rather than the SMS Retriever API: the retriever
  /// only fires for a message that ends in this app's signing hash, and the
  /// DLT-approved template ("1234 is your OTP to login to Wealthcon Neslife…")
  /// has no room for one. Consent needs no hash and no SMS permission — which
  /// Play would refuse for a login screen anyway — at the cost of one system
  /// sheet the user taps "Allow" on. What it returns lands in the same field
  /// typing does, so a completed code submits exactly as a typed one would.
  Future<void> _listenForSms() async {
    if (!_canReadSms) return;

    final result = await SmartAuth.instance.getSmsWithUserConsentApi();
    if (!mounted || !result.hasData) return;

    final code = _extractCode(result.requireData.sms);
    if (code == null || _controller.isBusy) return;

    _codeTextController.text = code;
    _controller.changeCode(code);
    _verify();
  }

  /// "2301 is your OTP…" — the number right before "is your OTP", falling back
  /// to the first standalone run of exactly [OtpCode.length] digits, so a
  /// reworded template still fills rather than silently doing nothing.
  static String? _extractCode(String sms) {
    const n = OtpCode.length;
    final preferred = RegExp(
      r'\b(\d{'
      '$n'
      r'})\b(?=\s+is\s+your\s+OTP)',
      caseSensitive: false,
    ).firstMatch(sms);
    if (preferred != null) return preferred.group(1);
    return RegExp(
      r'(?<!\d)\d{'
      '$n'
      r'}(?!\d)',
    ).firstMatch(sms)?.group(0);
  }

  void _autoFillOtp() {
    if (_hasAutoVerified) return;
    final codeToFill = widget.args.challenge.code;
    if (codeToFill != null &&
        codeToFill.isNotEmpty &&
        _codeTextController.text.isEmpty) {
      _codeTextController.text = codeToFill;
      _controller.changeCode(codeToFill);
      if (_controller.canVerify && !_controller.isBusy) {
        _hasAutoVerified = true;
        _verify();
      }
    }
  }

  @override
  void dispose() {
    if (_canReadSms) SmartAuth.instance.removeUserConsentApiListener();
    _codeTextController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_controller.canVerify) return;

    FocusScope.of(context).unfocus();
    final succeeded = await _controller.verify(role: widget.args.role);
    if (!mounted) return;

    if (!succeeded) {
      _showError();
      return;
    }

    // Where they belong is the same question a cold launch asks, so it is asked
    // in the same place: an administrator lands on the queue, a doctor under
    // review on their status screen, and only an actual patient in the patient
    // flow.
    final entry = await _controller.destinationAfterSignIn(widget.args.role);
    if (!mounted) return;

    // Two destinations end the session rather than open a screen: the number is
    // registered under the other journey, or the server does not recognise the
    // account at all. Both are handled here because both have the same answer —
    // end the session and say why. A refused journey that leaves a token behind
    // is one restart away from being the journey the app opens on.
    if (entry.destination == StartDestination.roleConflict ||
        entry.destination == StartDestination.sessionExpired) {
      await _controller.abandonSession();
      if (!mounted) return;

      AppSnackBar.error(
        context,
        entry.notice ??
            'This number is already registered under a different role.',
      );

      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
      return;
    }

    // The lookups could not answer, but the code just verified so the session
    // itself is sound. Back to the role choice with a warning rather than on
    // into either app: the alternative is the patient profile form, which is
    // the wrong screen for a doctor, or the certificate form, which is the
    // wrong screen for anyone whose registration could not be read. The
    // session is kept, so the next launch resolves this without another code.
    if (entry.destination == StartDestination.landing && entry.notice != null) {
      AppSnackBar.warning(context, entry.notice!);

      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
      return;
    }

    // The auth screens behind this are not worth returning to.
    Navigator.of(context).pushNamedAndRemoveUntil(
      switch (entry.destination) {
        StartDestination.adminQueue => AppRoutes.adminQueue,
        StartDestination.doctorSetup => AppRoutes.doctorProfileSetup,
        StartDestination.doctorPending => AppRoutes.doctorApplicationPending,
        StartDestination.doctorApproved => AppRoutes.doctorApplicationApproved,
        StartDestination.doctorHome => AppRoutes.doctorHome,
        StartDestination.home => AppRoutes.home,
        // The first two are unreachable — handled above — but the switch stays
        // exhaustive so adding a destination is a compile error rather than a
        // silent fall-through into the wrong app.
        StartDestination.roleConflict ||
        StartDestination.sessionExpired ||
        StartDestination.registrationAbandoned ||
        StartDestination.completeProfile ||
        StartDestination.landing => AppRoutes.completeProfile,
      },
      (route) => false,
      // The pending screen needs the application; the rest read the role.
      arguments: entry.application ?? widget.args.role,
    );
  }

  Future<void> _resend() async {
    final succeeded = await _controller.resend();
    if (!mounted) return;

    if (!succeeded) {
      _showError();
      return;
    }

    _codeTextController.clear();
    AppSnackBar.success(context, 'A new code is on its way.');

    // The consent listener is one-shot and has likely fired, been dismissed or
    // timed out for the old code by now, so it is armed again for the new one.
    if (_canReadSms) {
      await SmartAuth.instance.removeUserConsentApiListener();
      if (mounted) _listenForSms();
    }
  }

  void _showError() {
    final message = _controller.errorMessage;
    if (message == null) return;

    AppSnackBar.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final phone = widget.args.phoneNumber;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppTopBar(title: 'OTP Verification'),
                Padding(
                  padding: EdgeInsets.only(
                    top: sizing.spacingXl,
                    left: sizing.screenPaddingH,
                    right: sizing.screenPaddingH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Enter OTP'), style: sizing.text.screenTitle),
                      SizedBox(height: sizing.spacingXs),
                      Text(
                        tr("We've sent a {length}-digit code to {phone}", {
                          'length': OtpCode.length,
                          'phone':
                              '${phone.country.dialCode} ${phone.formattedNational}',
                        }),
                        style: sizing.text.screenSubtitle,
                      ),
                      SizedBox(height: sizing.spacingXxl),
                      OtpInput(
                        length: OtpCode.length,
                        controller: _codeTextController,
                        enabled: !_controller.isBusy,
                        hasError: _controller.errorMessage != null,
                        onChanged: _controller.changeCode,
                        onCompleted: (_) => _verify(),
                      ),
                      SizedBox(height: sizing.spacingXxl),
                      ResendCountdown(
                        countdown: _controller.resendCountdown,
                        canResend: _controller.canResend,
                        isResending: _controller.isResending,
                        onResend: _resend,
                      ),
                      SizedBox(height: sizing.spacingXxl),
                      AppButton.primary(
                        label: 'Verify & Proceed',
                        isLoading: _controller.isVerifying,
                        onPressed: _controller.canVerify ? _verify : null,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(height: sizing.screenPaddingV),
              ],
            );
          },
        ),
      ),
    );
  }
}
