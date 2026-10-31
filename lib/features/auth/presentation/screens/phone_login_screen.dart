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
import '../../../../core/widgets/app_version_label.dart';
import '../../../../core/widgets/hero_sheet_page.dart';
import '../../../onboarding/domain/entities/user_role.dart';
import '../../../../core/widgets/app_logo.dart';
import '../controllers/phone_login_controller.dart';
import '../../domain/entities/phone_number.dart';
import 'otp_verification_screen.dart';
import '../widgets/legal_notice.dart';
import '../widgets/phone_number_field.dart';

/// Step one of the OTP login: collect the user's mobile number.
///
/// Laid out as a brand-gradient hero with a white sheet rising over it. The
/// split is doing work rather than decoration: above the sheet is the app
/// introducing itself, inside it is the one thing the user has to do. The edge
/// between them also gives the form something to sit against when the keyboard
/// is up — on the previous full-white screen the title and the field floated on
/// the same surface, so nothing marked where the reading stopped and the typing
/// began.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key, this.role});

  /// The journey chosen on the landing screen, carried through to the app.
  final UserRole? role;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  late final PhoneLoginController _controller = sl<PhoneLoginController>();
  final TextEditingController _phoneTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _suggestSimNumber());
  }

  static bool get _canHintNumber =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Offers the SIM's own number through Google's Phone Number Hint sheet.
  ///
  /// No permission is involved — Play services shows the numbers and hands
  /// back only the one the user taps. Dismissing the sheet, a device with no
  /// SIM, or iOS all leave the field as it was, so typing stays the fallback
  /// rather than a separate path.
  Future<void> _suggestSimNumber() async {
    if (!_canHintNumber || _phoneTextController.text.isNotEmpty) return;

    final result = await SmartAuth.instance.requestPhoneNumberHint();
    if (!mounted || !result.hasData) return;

    final digits = _nationalDigits(result.requireData);
    if (digits == null || _phoneTextController.text.isNotEmpty) return;

    final country = _controller.phoneNumber.country;
    final formatted = PhoneNumber.formatDigits(digits, country);
    _phoneTextController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _controller.changeDigits(digits);
  }

  /// `+91 98765 43210`, `09876543210` or `9876543210` → `9876543210`; null for
  /// a number from another country, which this field cannot take.
  String? _nationalDigits(String hint) {
    final country = _controller.phoneNumber.country;
    final dial = country.dialCode.replaceAll('+', '');
    var digits = hint.replaceAll(RegExp(r'\D'), '');

    if (hint.trim().startsWith('+')) {
      if (!digits.startsWith(dial)) return null;
      digits = digits.substring(dial.length);
    } else if (digits.length == country.digitCount + dial.length &&
        digits.startsWith(dial)) {
      digits = digits.substring(dial.length);
    } else if (digits.length == country.digitCount + 1 &&
        digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    return digits.length == country.digitCount ? digits : null;
  }

  @override
  void dispose() {
    _phoneTextController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_controller.canSubmit) return;

    FocusScope.of(context).unfocus();
    final succeeded = await _controller.submit();
    if (!mounted) return;

    if (!succeeded) {
      _showError();
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.otpVerification,
      arguments: OtpVerificationArgs(
        phoneNumber: _controller.phoneNumber,
        challenge: _controller.challenge!,
        role: widget.role,
      ),
    );
  }

  void _showError() {
    final message = _controller.errorMessage;
    if (message == null) return;

    // A cooldown is not a fault — the number is fine and the code is on its
    // way. Colouring it red would tell the user to fix something that is not
    // broken, and the thing to do is wait.
    if (_controller.cooldownRemaining != null) {
      AppSnackBar.warning(context, message);
      return;
    }

    AppSnackBar.error(context, message);
  }

  void _openLegal(String document) {
    // TODO(legal): open the hosted document once the URLs are available.
    AppSnackBar.info(
      context,
      tr('{document} is coming soon.', {'document': tr(document)}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons: it is the hero, not the sheet, that reaches the
      // top of the screen. The navigation bar still sits on the white sheet.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: HeroSheetPage(
        hero: _AuthHero(role: widget.role),
        sheet: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return _LoginForm(
              controller: _controller,
              role: widget.role,
              phoneTextController: _phoneTextController,
              onSubmit: _submit,
              onTermsTap: () => _openLegal('Terms of Service'),
              onPrivacyTap: () => _openLegal('Privacy Policy'),
            );
          },
        ),
      ),
    );
  }
}

/// The gradient half: the back affordance, the brand mark, and what the screen
/// is asking for.
class _AuthHero extends StatelessWidget {
  const _AuthHero({this.role});

  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppTopBar(title: 'Sign in', variant: AppTopBarVariant.onBrand),
        Padding(
          padding: EdgeInsets.only(
            left: sizing.screenPaddingH,
            right: sizing.screenPaddingH,
            bottom: sizing.spacingXxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: sizing.spacingXs),
              const _AuthBrandMark(),
              SizedBox(height: sizing.spacingLg),
              Text(
                tr("Let's Get Started"),
                style: sizing.text.screenTitle.copyWith(
                  color: AppColors.onBrand,
                ),
              ),
              SizedBox(height: sizing.spacingXs),
              Text(
                tr(
                  'Enter your mobile number and we will text you a '
                  'verification code.',
                ),
                style: sizing.text.leadParagraph.copyWith(
                  color: AppColors.onBrandMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The white half: the number, the action, and the terms it is taken under.
class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.controller,
    required this.phoneTextController,
    required this.onSubmit,
    required this.onTermsTap,
    required this.onPrivacyTap,
    this.role,
  });

  final PhoneLoginController controller;
  final TextEditingController phoneTextController;
  final VoidCallback onSubmit;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  /// The journey being signed in to, echoed back at the top of the sheet.
  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return HeroSheet(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LegalNotice(onTermsTap: onTermsTap, onPrivacyTap: onPrivacyTap),
          SizedBox(height: sizing.spacingXs),
          const AppVersionLabel(),
        ],
      ),
      children: [
        // Which journey this sign-in is for. The landing screen already asked,
        // and it decides which side opens after the code — so saying it here
        // is the last point at which going back costs nothing.
        if (role case final role?) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: _RoleChip(role: role),
          ),
          SizedBox(height: sizing.spacingLg),
        ],
        PhoneNumberField(
          controller: phoneTextController,
          country: controller.phoneNumber.country,
          enabled: !controller.isBusy,
          onDigitsChanged: controller.changeDigits,
          onSubmitted: onSubmit,
        ),
        SizedBox(height: sizing.spacingXl),
        AppButton.primary(
          label: 'Continue',
          isLoading: controller.isRequestingOtp,
          onPressed: controller.canSubmit ? onSubmit : null,
        ),
      ],
    );
  }
}

/// The app's mark, at the size the auth screens use.
///
/// Kept rather than dropped when the hero took over the top of the screen: the
/// login screen is reached both from the landing screen and from a session that
/// just ended, and in the second case it is the first thing the user sees after
/// being put back to the start. Something recognisable there is worth the
/// vertical space.
class _AuthBrandMark extends StatelessWidget {
  const _AuthBrandMark();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AppLogoMark(
      size: sizing.brandMarkSizeCompact,
      color: AppColors.onBrand,
    );
  }
}

/// "Continuing as Patient" — a read-only reminder of the journey chosen on the
/// landing screen.
///
/// Not a control. Changing it means going back one screen, which is a tap away
/// and unambiguous; a second place to pick a role before sign-in would leave
/// two answers to the same question on two screens. Once signed in, the switch
/// on either profile screen moves between the two sides.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingSm,
        vertical: sizing.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(sizing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            role == UserRole.doctor
                ? Icons.medical_services_outlined
                : Icons.person_outline_rounded,
            size: sizing.iconXs,
            color: AppColors.primaryDeep,
          ),
          SizedBox(width: sizing.spacingXxs),
          Text(
            tr('Continuing as {role}', {'role': tr(role.label)}),
            style: sizing.text.chipLabel.copyWith(color: AppColors.primaryDeep),
          ),
        ],
      ),
    );
  }
}
