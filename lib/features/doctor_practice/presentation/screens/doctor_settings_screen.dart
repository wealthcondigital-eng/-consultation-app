import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/app_switch_row.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/app_version_label.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../profile/presentation/widgets/profile_section.dart';
import '../../domain/entities/doctor_settings.dart';
import '../controllers/doctor_settings_controller.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Settings: what the doctor agrees to be pinged about.
///
/// The first switch is not decoration. `ConsultationsService` reads
/// `newConsultations` when choosing who to ring, so turning it off actually
/// stops consultations being offered — which is what the row says, and why it
/// is marked and warns when off. A doctor who switched it off by accident sees
/// a platform that has gone quiet, and would have no way to tell the two apart.
class DoctorSettingsScreen extends StatefulWidget {
  const DoctorSettingsScreen({super.key});

  @override
  State<DoctorSettingsScreen> createState() => _DoctorSettingsScreenState();
}

class _DoctorSettingsScreenState extends State<DoctorSettingsScreen> {
  late final DoctorSettingsController _controller =
      sl<DoctorSettingsController>();

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onChanged)
      ..load();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  /// Surfaces a change the backend refused. The switch has already reverted by
  /// the time this runs.
  void _onChanged() {
    final message = _controller.errorMessage;
    if (message == null || !mounted) return;

    _controller.acknowledgeError();
    AppSnackBar.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.canvas,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppTopBar(
              title: 'Settings',
              variant: AppTopBarVariant.outlined,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _Body(controller: _controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final DoctorSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    // Only when the *read* failed. A failed write leaves the rows on screen and
    // puts its message in a snackbar — the settings are still readable, and
    // replacing them with an error page would lose them.
    final readError = controller.hasLoaded ? null : controller.errorMessage;
    if (readError != null) {
      return AppErrorView(message: readError, onRetry: controller.load);
    }

    final toggles = DoctorNotificationToggle.values;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingMd,
        sizing.screenPaddingH,
        sizing.spacingXxl,
      ),
      children: [
        if (!controller.settings.newConsultations) ...[
          const _OfflineWarning(),
          SizedBox(height: sizing.spacingMd),
        ],
        ProfileSection(
          title: 'Notifications',
          child: ProfileCard(
            padded: false,
            children: [
              for (final (index, toggle) in toggles.indexed)
                AppSwitchRow(
                  label: toggle.label,
                  description: toggle.description,
                  value: toggle.from(controller.settings),
                  isCritical: toggle.isCritical,
                  isBusy: controller.pending == toggle,
                  // Every row locks while any one is in flight, so two writes
                  // cannot race and land in the opposite order.
                  onChanged: controller.pending == null
                      ? (_) => controller.toggle(toggle)
                      : null,
                  showDivider: index < toggles.length - 1,
                ),
            ],
          ),
        ),
        SizedBox(height: sizing.spacingXl),
        const _PresenceNote(),
        SizedBox(height: sizing.spacingXl),
        const AppVersionLabel(),
      ],
    );
  }
}

/// What being off actually means, said where it can be acted on.
class _OfflineWarning extends StatelessWidget {
  const _OfflineWarning();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(width: sizing.hairline, color: AppColors.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_off_rounded,
            size: sizing.iconSm,
            color: AppColors.danger,
          ),
          SizedBox(width: sizing.spacingXs),
          Expanded(
            child: Text(
              tr(
                'Patients cannot reach you. Incoming consultations are off, so '
                'no calls will be offered to you even while you are online.',
              ),
              style: sizing.text.bodySmall.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// How this differs from the dial on the home screen.
///
/// Two controls that both stop calls arriving is a confusing pair, so the
/// difference is spelled out: one is a standing preference, the other is
/// whether you are at your desk right now.
class _PresenceNote extends StatelessWidget {
  const _PresenceNote();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: sizing.iconSm,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Text(
                  tr('This and the Online dial'),
                  style: sizing.text.cardTitle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: sizing.spacingXs),
          Text(
            tr(
              'The dial on your home screen is whether you are available right '
              'now, and it turns itself off if the app stops running. This is a '
              'standing preference: with it off, no consultation is offered to '
              'you whatever the dial says.',
            ),
            style: sizing.text.legalBody,
          ),
        ],
      ),
    );
  }
}
