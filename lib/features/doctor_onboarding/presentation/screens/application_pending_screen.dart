import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/doctor_application.dart';
import '../controllers/application_status_controller.dart';
import '../widgets/status_hero.dart';
import '../../../../core/l10n/tr.dart';

/// Shown from the moment a registration is filed until the board answers.
///
/// Nothing here for the doctor to do — the screen watches, and moves on by
/// itself once the verification lands.
class ApplicationPendingScreen extends StatefulWidget {
  const ApplicationPendingScreen({super.key, required this.application});

  final DoctorApplication application;

  @override
  State<ApplicationPendingScreen> createState() =>
      _ApplicationPendingScreenState();
}

class _ApplicationPendingScreenState extends State<ApplicationPendingScreen> {
  late final ApplicationStatusController _controller =
      sl<ApplicationStatusController>();

  bool _handledApproval = false;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onChanged)
      ..watch(widget.application);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!_controller.isApproved || _handledApproval || !mounted) return;

    // Fires once: the controller keeps notifying as the screen settles.
    _handledApproval = true;
    Navigator.of(
      context,
    ).pushReplacementNamed(AppRoutes.doctorApplicationApproved);
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
      // There is nothing behind this screen: the registration is filed and the
      // form is gone.
      child: PopScope(
        canPop: false,
        child: ResponsivePage(
          backgroundColor: AppColors.canvas,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Padding(
                padding: sizing.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatusHero(
                      icon: Icons.schedule_rounded,
                      surface: AppColors.primarySurface,
                      foreground: AppColors.primary,
                      semanticsLabel: tr('Waiting on verification'),
                    ),
                    SizedBox(height: sizing.spacingXxxl),
                    Text(
                      tr('Registration Submitted!'),
                      style: sizing.text.screenTitleCompact,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: sizing.spacingSm),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: sizing.w(320)),
                      child: Text(
                        tr(
                          _controller.errorMessage ??
                              'Your application is under verification. We will '
                                  'notify you once your profile is approved.',
                        ),
                        style: sizing.text.helperText,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: sizing.spacingXxl),
                    Text(
                      tr(
                        'You can close the app. We will send you a notification.',
                      ),
                      style: sizing.text.complianceNote,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
