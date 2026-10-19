import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/exit_confirmation.dart';
import '../../../../core/widgets/hero_sheet_page.dart';
import '../../domain/entities/user_role.dart';
import '../controllers/landing_controller.dart';
import '../widgets/brand_header.dart';
import '../widgets/role_actions.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Where a launch with nobody signed in comes to rest: brand mark plus the role
/// choice that starts the patient or doctor journey.
///
/// The splash hands over to it on the same gradient with the same lockup, so
/// what changes between the two screens is that a question has appeared — not
/// that the app has been replaced by a different one.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late final LandingController _controller = sl<LandingController>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRole(UserRole role) async {
    final navigator = Navigator.of(context);

    final succeeded = await _controller.chooseRole(role);
    if (!mounted) return;

    if (!succeeded) {
      final message = _controller.errorMessage;
      if (message != null) {
        AppSnackBar.error(context, message);
      }
      return;
    }

    // Both journeys start at the same phone login: the role rides along with
    // it, and the OTP screen sends each one to its own next step.
    navigator.pushNamed(AppRoutes.phoneLogin, arguments: role);
  }

  @override
  Widget build(BuildContext context) {
    // Nothing behind this screen, so the back gesture would close the
    // app outright — see [ExitConfirmation].
    return ExitConfirmation(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Light status bar icons: the gradient runs to the top of the screen,
        // and the white sheet only reaches the bottom.
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.surface,
          systemNavigationBarIconBrightness: AppColors.navIconBrightness,
        ),
        // The brand takes the spare height and the actions keep to the bottom of
        // the screen, which is both where the thumb is and where the eye arrives
        // after reading the lockup.
        child: HeroSheetPage(
          expandHero: true,
          hero: const BrandHeader(),
          sheet: RoleActions(
            controller: _controller,
            onRoleSelected: _handleRole,
          ),
        ),
      ),
    );
  }
}
