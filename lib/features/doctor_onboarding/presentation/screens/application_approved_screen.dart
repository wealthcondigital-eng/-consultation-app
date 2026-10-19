import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../widgets/status_hero.dart';
import '../../../../core/l10n/tr.dart';

/// The doctor is verified. From here they either set their practice up or go
/// straight to the app and do it later.
class ApplicationApprovedScreen extends StatelessWidget {
  const ApplicationApprovedScreen({super.key});

  void _completeSetup(BuildContext context) {
    // `true` marks this as the wizard's first step, which is what makes
    // Continue carry on to Set Availability and, from there, to the doctor's
    // home screen rather than back up the stack.
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.doctorPracticeSetup, arguments: true);
  }

  void _doItLater(BuildContext context) {
    // Straight into the app, with the onboarding stack discarded.
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.doctorHome, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.canvas,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        child: Padding(
          padding: sizing.screenPadding,
          child: Column(
            children: [
              const Spacer(),
              StatusHero(
                icon: Icons.check_circle_outline_rounded,
                surface: AppColors.badgeSurface,
                foreground: AppColors.success,
                semanticsLabel: tr('Profile verified'),
              ),
              SizedBox(height: sizing.spacingXxxl),
              Text(
                tr('Congratulations!'),
                style: sizing.text.screenTitleCompact,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: sizing.spacingSm),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: sizing.w(320)),
                child: Text(
                  tr(
                    'Your profile has been verified successfully. Complete your '
                    'practice setup to start consulting.',
                  ),
                  style: sizing.text.helperText,
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              AppButton.primary(
                label: 'Complete Setup',
                onPressed: () => _completeSetup(context),
              ),
              SizedBox(height: sizing.spacingSm),
              TextButton(
                onPressed: () => _doItLater(context),
                child: Text(
                  tr('Do it Later'),
                  style: sizing.text.countdownValue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
