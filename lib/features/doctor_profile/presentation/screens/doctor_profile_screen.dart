import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/media/profile_photo_picker.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/appearance_row.dart';
import '../../../../core/widgets/language_row.dart';
import '../../../../core/update/app_update_prompt.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_version_label.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../doctor_onboarding/domain/entities/doctor_availability.dart';
import '../../../doctor_onboarding/presentation/screens/practice_setup_screen.dart'
    show feeSummaryText;
import '../../../doctor_onboarding/presentation/screens/set_availability_screen.dart'
    show availabilitySummaryText;
import '../../../home/presentation/widgets/doctor_stats_row.dart';
import '../../../profile/presentation/widgets/profile_section.dart';
import '../../../recordings/presentation/widgets/recordings_section.dart';
import '../controllers/doctor_profile_controller.dart';
import '../widgets/doctor_profile_header.dart';

/// The doctor's profile as a standalone route.
///
/// The doctor shell hosts [DoctorProfileView] directly instead, so the nav bar
/// stays put when Profile is selected as a tab.
class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

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
        child: DoctorProfileView(),
      ),
    );
  }
}

/// Profile: who the doctor is, then everything about their practice they can
/// change — availability first, because it is the one they change weekly.
///
/// This screen used to be the availability form itself: tapping Profile in the
/// nav bar opened Set Availability, and there was nowhere to see the doctor's
/// own details at all. Availability is one setting among several, so it is a
/// row here and a screen of its own behind it.
///
/// Carries no page shell of its own so it can sit inside one that already
/// exists — nesting `ResponsivePage` would double the Scaffold and SafeArea.
class DoctorProfileView extends StatefulWidget {
  const DoctorProfileView({super.key});

  @override
  State<DoctorProfileView> createState() => _DoctorProfileViewState();
}

class _DoctorProfileViewState extends State<DoctorProfileView> {
  late final DoctorProfileController _controller =
      sl<DoctorProfileController>();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opens a route and reloads if it reported a change.
  ///
  /// The fee screen and the edit form both write fields this screen renders, so
  /// coming back from either without re-reading would leave a stale summary
  /// under the row that had just been changed.
  Future<void> _openAndReload(String route) async {
    await Navigator.of(context).pushNamed(route);
    if (mounted) await _controller.load();
  }

  Future<void> _openAvailability() async {
    final saved = await Navigator.of(
      context,
    ).pushNamed<DoctorAvailability>(AppRoutes.doctorAvailability);

    // The screen hands back what it stored, so the summary under the row is
    // right the moment the doctor lands back here — no second round trip to
    // read what this app just wrote.
    if (saved != null && mounted) _controller.applyAvailability(saved);
  }

  /// Camera or gallery, then upload. A third option removes the photo, and
  /// only when there is one to remove.
  Future<void> _changePhoto() async {
    final sizing = context.sizing;
    final hasPhoto = _controller.dashboard?.photoUrl != null;

    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(sizing.radiusXl),
        ),
      ),
      builder: (context) => _PhotoSheet(canRemove: hasPhoto),
    );

    if (choice == null) return;

    switch (choice) {
      case _PhotoChoice.camera:
        await _controller.changePhoto(PhotoSource.camera);
      case _PhotoChoice.gallery:
        await _controller.changePhoto(PhotoSource.gallery);
      case _PhotoChoice.remove:
        await _controller.removePhoto();
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogOut = await AppConfirmDialog.show(
      context,
      title: 'Log out?',
      message:
          'You will be taken offline and patients will not be able to '
          'reach you until you sign back in.',
      confirmLabel: 'Log out',
      cancelLabel: 'Stay signed in',
      icon: Icons.logout_rounded,
      tone: AppConfirmTone.destructive,
    );

    if (!shouldLogOut || !mounted) return;

    final signedOut = await _controller.signOut();
    if (!signedOut || !mounted) return;

    // The whole stack goes: nothing behind this screen should survive a doctor
    // signing out.
    await Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        // No top bar. The hero header names the screen by showing whose it is,
        // and a bar reading "Profile" above a photo of you is a caption on a
        // caption — the room it took is the gradient's now.
        return _Body(
          controller: _controller,
          onOpen: _openAndReload,
          onOpenAvailability: _openAvailability,
          onChangePhoto: _changePhoto,
          onLogout: _confirmLogout,
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.onOpen,
    required this.onOpenAvailability,
    required this.onChangePhoto,
    required this.onLogout,
  });

  final DoctorProfileController controller;

  /// Pushes a named route and reloads on the way back.
  final ValueChanged<String> onOpen;

  final VoidCallback onOpenAvailability;
  final VoidCallback onChangePhoto;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    final dashboard = controller.dashboard;
    if (dashboard == null) {
      return _ProfileError(
        message: controller.errorMessage ?? 'Your profile is not available.',
        onRetry: controller.load,
      );
    }

    final practice = controller.practice;

    return AppRefreshIndicator(
      onRefresh: controller.load,
      // No horizontal padding on the list itself: the hero header bleeds to
      // both edges and under the status bar, and everything below it is inset
      // by the Padding further down.
      child: ListView(
        padding: EdgeInsets.only(bottom: sizing.spacingXxl),
        children: [
          DoctorProfileHeader(
            dashboard: dashboard,
            onEdit: () => onOpen(AppRoutes.doctorEditProfile),
            onChangePhoto: onChangePhoto,
            isSavingPhoto: controller.isSavingPhoto,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sizing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: sizing.spacingLg),
                // An update the doctor put off on the sheet waits here.
                const AppUpdateCard(),
                // Moved here from the home screen, which now leads with what
                // is ahead of the doctor rather than what the day added up to.
                ProfileSection(
                  title: "Today's Statistics",
                  actionLabel: 'Earnings',
                  onAction: () => onOpen(AppRoutes.doctorEarnings),
                  child: DoctorStatsRow(stats: dashboard.stats),
                ),
                SizedBox(height: sizing.spacingXl),
                ProfileSection(
                  title: 'Practice',
                  child: ProfileCard(
                    padded: false,
                    children: [
                      ProfileActionRow(
                        icon: Icons.event_available_rounded,
                        label: 'Set Availability',
                        // Null until the schedule has been read: an empty subtitle
                        // is better than telling a doctor with a full week that they
                        // have nothing set up.
                        subtitle: switch (controller.availability) {
                          final availability? => availabilitySummaryText(
                            availability,
                          ),
                          null => null,
                        },
                        onTap: onOpenAvailability,
                      ),
                      ProfileActionRow(
                        icon: Icons.payments_rounded,
                        label: 'Consultation Fees',
                        // A subtitle, not a `value`: two prices do not fit beside a
                        // label and a chevron, which is what the row's own comment
                        // says about anything longer than a few characters.
                        subtitle: switch (practice) {
                          final practice? => feeSummaryText(practice),
                          null => null,
                        },
                        // The practice-setup screen, which is where the fee is
                        // chosen. It is reachable after approval as well as during
                        // it, which is why `PATCH /doctors/me/fee` creates the
                        // record rather than answering 404.
                        onTap: () => onOpen(AppRoutes.doctorPracticeSetup),
                      ),
                      ProfileActionRow(
                        icon: Icons.groups_rounded,
                        label: 'My Patients',
                        onTap: () => onOpen(AppRoutes.doctorPatients),
                      ),
                      ProfileActionRow(
                        icon: Icons.receipt_long_rounded,
                        label: 'Consultation History',
                        onTap: () => onOpen(AppRoutes.doctorAppointments),
                      ),
                      ProfileActionRow(
                        icon: Icons.rate_review_rounded,
                        label: 'Patient Reviews',
                        subtitle: 'What patients wrote after a consultation',
                        onTap: () => onOpen(AppRoutes.doctorReviews),
                      ),
                      ProfileActionRow(
                        icon: Icons.account_balance_rounded,
                        label: 'Bank & Payouts',
                        onTap: () => onOpen(AppRoutes.doctorBankAccount),
                      ),
                      ProfileActionRow(
                        icon: Icons.workspace_premium_rounded,
                        label: 'Credentials & Documents',
                        onTap: () => onOpen(AppRoutes.doctorCredentials),
                      ),
                      // Recordings patients made of their consultations with
                      // this doctor, by patient.
                      const RecordingsEntryRow(),
                    ],
                  ),
                ),
                SizedBox(height: sizing.spacingXl),
                ProfileSection(
                  title: 'Account',
                  child: ProfileCard(
                    padded: false,
                    children: [
                      ProfileActionRow(
                        icon: Icons.notifications_rounded,
                        label: 'Notifications',
                        subtitle: 'What we ping you about',
                        onTap: () => onOpen(AppRoutes.doctorSettings),
                      ),
                      const LanguageRow(),
                      const AppearanceRow(),
                      ProfileActionRow(
                        icon: Icons.trending_up_rounded,
                        label: 'Earnings',
                        onTap: () => onOpen(AppRoutes.doctorEarnings),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sizing.spacingXl),
                _LogoutButton(
                  isBusy: controller.isSigningOut,
                  onPressed: onLogout,
                ),
                SizedBox(height: sizing.spacingMd),
                const AppVersionLabel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the photo sheet offers.
enum _PhotoChoice { camera, gallery, remove }

class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet({required this.canRemove});

  /// False when there is no photo to take away, so the destructive option is
  /// absent rather than present and inert.
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: sizing.spacingSm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(tr('Take a photo'), style: sizing.text.fieldValue),
              onTap: () => Navigator.of(context).pop(_PhotoChoice.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(
                tr('Choose from gallery'),
                style: sizing.text.fieldValue,
              ),
              onTap: () => Navigator.of(context).pop(_PhotoChoice.gallery),
            ),
            if (canRemove)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                title: Text(
                  tr('Remove photo'),
                  style: sizing.text.fieldValue.copyWith(
                    color: AppColors.danger,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(_PhotoChoice.remove),
              ),
          ],
        ),
      ),
    );
  }
}

/// Outlined rather than filled: destructive, but not the screen's main action.
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.isBusy, required this.onPressed});

  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return OutlinedButton(
      onPressed: isBusy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(sizing.buttonHeight),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.danger,
        side: BorderSide(color: AppColors.danger),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sizing.radiusMd),
        ),
      ),
      child: isBusy
          ? SizedBox.square(
              dimension: sizing.iconSm,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.danger),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout_rounded, size: sizing.iconSm),
                SizedBox(width: sizing.spacingXs),
                Text(
                  tr('Logout'),
                  style: sizing.text.buttonLabel.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Center(
      child: Padding(
        padding: sizing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: sizing.r(40),
              color: AppColors.textTertiary,
            ),
            SizedBox(height: sizing.spacingSm),
            Text(
              tr(message),
              style: sizing.text.bodySmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: sizing.spacingXs),
            TextButton(
              onPressed: onRetry,
              child: Text(tr('Retry'), style: sizing.text.sectionAction),
            ),
          ],
        ),
      ),
    );
  }
}
