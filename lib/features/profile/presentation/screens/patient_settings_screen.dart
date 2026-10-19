import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/app_switch_row.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/app_version_label.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/notification_settings.dart';
import '../controllers/patient_settings_controller.dart';
import '../widgets/profile_section.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Settings: what the patient agrees to be contacted about.
///
/// Every switch here is a real preference the backend acts on. A settings
/// screen full of rows that only remember themselves is worse than no settings
/// screen, because it makes a promise the platform then breaks.
class PatientSettingsScreen extends StatefulWidget {
  const PatientSettingsScreen({super.key});

  @override
  State<PatientSettingsScreen> createState() => _PatientSettingsScreenState();
}

class _PatientSettingsScreenState extends State<PatientSettingsScreen> {
  late final PatientSettingsController _controller =
      sl<PatientSettingsController>();

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

  final PatientSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    // Only when the *read* failed. A failed write leaves the rows on screen
    // and puts its message in a snackbar — the settings are still perfectly
    // readable, and replacing them with an error page would lose them.
    final readError = controller.hasLoaded ? null : controller.errorMessage;
    if (readError != null) {
      return AppErrorView(message: readError, onRetry: controller.load);
    }

    final toggles = PatientNotificationToggle.values;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingMd,
        sizing.screenPaddingH,
        sizing.spacingXxl,
      ),
      children: [
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
        _PrivacyNote(),
        SizedBox(height: sizing.spacingXl),
        const AppVersionLabel(),
      ],
    );
  }
}

/// Where the rest of the settings are, and why they are not here.
///
/// A screen with four switches invites the question "is that all?". Saying what
/// lives elsewhere — the phone number that is the account's identity, the
/// medical record — is cheaper than a support conversation.
class _PrivacyNote extends StatelessWidget {
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
                Icons.lock_outline_rounded,
                size: sizing.iconSm,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Text(
                  tr('Your data'),
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
              'Your name, date of birth and blood group are edited from '
              'Personal Details, and your conditions and medication from '
              'Medical History. Your phone number is your sign-in and cannot '
              'be changed here — verifying a new one needs a fresh code.',
            ),
            style: sizing.text.legalBody,
          ),
        ],
      ),
    );
  }
}
