import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/media/profile_photo_picker.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/appearance_row.dart';
import '../../../../core/widgets/language_row.dart';
import '../../../../core/update/app_update_prompt.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/profile_hero_header.dart';
import '../../../../core/widgets/app_version_label.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/medical_history.dart';
import '../../domain/entities/patient_account.dart';
import '../controllers/patient_profile_controller.dart';
import '../widgets/medical_history_card.dart';
import '../widgets/patient_stats_card.dart';
import '../widgets/profile_section.dart';

/// My Profile as a standalone route: the view inside the shared page shell.
///
/// The patient shell hosts [PatientProfileView] directly instead, so the nav
/// bar stays put when Profile is selected as a tab.
class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

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
        child: PatientProfileView(),
      ),
    );
  }
}

/// My Profile: who the patient is, what their record says, and the account
/// controls.
///
/// Carries no page shell of its own so it can sit inside one that already
/// exists — nesting `ResponsivePage` would double the Scaffold and SafeArea.
class PatientProfileView extends StatefulWidget {
  const PatientProfileView({super.key});

  @override
  State<PatientProfileView> createState() => _PatientProfileViewState();
}

class _PatientProfileViewState extends State<PatientProfileView> {
  late final PatientProfileController _controller =
      sl<PatientProfileController>();

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

  /// Surfaces a photo change that failed. The avatar has already reverted by
  /// the time this runs.
  void _onChanged() {
    final message = _controller.errorMessage;
    if (message == null || !mounted) return;

    // Only while there is an account to show. Before the first load, the
    // message belongs on the error view rather than in a snackbar over a
    // spinner.
    if (_controller.account == null) return;

    _controller.acknowledgeError();
    AppSnackBar.error(context, message);
  }

  Future<void> _editDetails(PatientAccount account) async {
    final saved = await Navigator.of(
      context,
    ).pushNamed<Object>(AppRoutes.editProfile, arguments: account);

    if (!mounted) return;

    switch (saved) {
      // The record the server answered the save with — the backend's own word
      // on what it stored, so it goes on screen as is.
      case final PatientAccount stored:
        await _controller.applySavedAccount(stored);
      // Saved, but no record came back: read it.
      case true:
        await _controller.load();
    }
  }

  /// Opens the medical-history form and folds back what it stored.
  ///
  /// The screen hands the record over, so the summary card is right the moment
  /// the patient lands back here — no second round trip to read what this app
  /// just wrote.
  Future<void> _editMedicalHistory() async {
    final saved = await Navigator.of(
      context,
    ).pushNamed<MedicalHistory>(AppRoutes.medicalHistory);

    if (saved != null && mounted) await _controller.load();
  }

  /// Camera or gallery, then upload. A third option removes the photo, and only
  /// when there is one to remove.
  Future<void> _changePhoto() async {
    final account = _controller.account;
    if (account == null) return;

    final sizing = context.sizing;

    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(sizing.radiusXl),
        ),
      ),
      builder: (context) => _PhotoSheet(canRemove: account.avatarUrl != null),
    );

    if (choice == null || !mounted) return;

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
    final navigator = Navigator.of(context);

    final shouldLogOut = await AppConfirmDialog.show(
      context,
      title: 'Log out?',
      message:
          'You will need your phone number and a new code to sign back '
          'in. Your consultations and medical record stay on your account.',
      confirmLabel: 'Log out',
      cancelLabel: 'Stay signed in',
      icon: Icons.logout_rounded,
      tone: AppConfirmTone.destructive,
    );

    if (!shouldLogOut) return;

    final signedOut = await _controller.signOut();
    if (!signedOut) return;

    // The whole stack goes: nothing behind this screen should survive a
    // patient signing out. The navigator was captured before the awaits, so no
    // `BuildContext` is read across them.
    await navigator.pushNamedAndRemoveUntil(
      AppRoutes.landing,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        // No top bar. The hero header names the screen by showing whose it is,
        // and a bar reading "My Profile" above a photo of you is a caption on a
        // caption — the room it took is the gradient's now.
        return _Body(
          controller: _controller,
          onLogout: _confirmLogout,
          onEditDetails: _editDetails,
          onEditMedicalHistory: _editMedicalHistory,
          onChangePhoto: _changePhoto,
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.onLogout,
    required this.onEditDetails,
    required this.onEditMedicalHistory,
    required this.onChangePhoto,
  });

  final PatientProfileController controller;
  final VoidCallback onLogout;
  final ValueChanged<PatientAccount> onEditDetails;
  final VoidCallback onEditMedicalHistory;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    final account = controller.account;
    if (account == null) {
      return AppErrorView(
        message: controller.errorMessage ?? 'Your profile is not available.',
        onRetry: controller.load,
      );
    }

    final dashboard = controller.dashboard;

    return AppRefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: EdgeInsets.only(bottom: sizing.spacingXxl),
        children: [
          ProfileHeroHeader(
            name: account.fullName,
            initials: account.initials,
            // The phone number rather than an empty line. Email is optional
            // and often blank; the number is the account's identity and is
            // always there.
            subtitle: account.email.isEmpty
                ? account.phoneNumber
                : account.email,
            photoPath: account.avatarUrl,
            isSavingPhoto: controller.isSavingPhoto,
            onChangePhoto: onChangePhoto,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sizing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pulled up so the card overlaps the gradient's lower edge.
                // The overlap is what ties the two together — without it the
                // banner reads as a separate screen sitting on top of a list.
                Transform.translate(
                  offset: Offset(0, -sizing.spacingMd),
                  child: dashboard == null
                      // The figures could not be read. The profile is what this
                      // screen is for and is perfectly usable without them, so
                      // the card is simply absent.
                      ? const SizedBox.shrink()
                      : PatientStatsCard(
                          dashboard: dashboard,
                          onCompleteProfile: () => onEditDetails(account),
                        ),
                ),
                // An update the patient put off on the sheet waits here.
                const AppUpdateCard(),
                SizedBox(height: sizing.spacingMd),
                ProfileSection(
                  title: 'Medical History',
                  actionLabel: 'Open',
                  onAction: onEditMedicalHistory,
                  child: MedicalHistoryCard(
                    // The empty record rather than hiding the card. A patient
                    // with no history recorded is exactly who this card should
                    // be asking, and the section used to disappear for them
                    // entirely.
                    history:
                        account.medicalHistory ?? const MedicalHistory.empty(),
                    onEdit: onEditMedicalHistory,
                  ),
                ),
                SizedBox(height: sizing.spacingXl),
                ProfileSection(
                  title: 'Personal Details',
                  actionLabel: 'Edit',
                  onAction: () => onEditDetails(account),
                  child: _PersonalDetails(account: account),
                ),
                SizedBox(height: sizing.spacingXl),
                ProfileSection(
                  title: 'Activity',
                  child: ProfileCard(
                    padded: false,
                    children: [
                      ProfileActionRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'My Appointments',
                        subtitle: 'Instant and scheduled consultations',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.patientAppointments),
                        showDivider: false,
                      ),
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
                        subtitle: 'What we contact you about',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.patientSettings),
                      ),
                      const LanguageRow(),
                      const AppearanceRow(showDivider: false),
                    ],
                  ),
                ),
                SizedBox(height: sizing.spacingXl),
                // Everything Play and the DPDP Act ask to be reachable from
                // inside the app: the notice, the policies, the terms, a way to
                // reach a person, and a way out. They are one section rather
                // than scattered through the profile because they are read
                // together — by a reviewer checking the listing, and by anyone
                // who has decided to leave.
                ProfileSection(
                  title: 'Legal & Support',
                  child: ProfileCard(
                    padded: false,
                    children: [
                      ProfileActionRow(
                        icon: Icons.shield_outlined,
                        label: 'Data Protection',
                        subtitle: 'What we collect, and your rights (DPDP)',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.dataProtection),
                      ),
                      ProfileActionRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Privacy Policy',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.privacyPolicy),
                      ),
                      ProfileActionRow(
                        icon: Icons.description_outlined,
                        label: 'Terms & Conditions',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.termsAndConditions),
                      ),
                      ProfileActionRow(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Cancellation & Refund Policy',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.cancellationAndRefund),
                      ),
                      ProfileActionRow(
                        icon: Icons.support_agent_rounded,
                        label: 'Contact Us',
                        subtitle: 'Email, phone, and the grievance officer',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.contactSupport),
                      ),
                      ProfileActionRow(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete Account',
                        subtitle: 'Erase your data permanently',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.deleteAccount),
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

class _PersonalDetails extends StatelessWidget {
  const _PersonalDetails({required this.account});

  final PatientAccount account;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Full Name', account.fullName),
      ('Email', account.email.isEmpty ? '—' : account.email),
      ('Phone Number', account.phoneNumber),
      ('Date of Birth', account.dateOfBirthLabel),
      if (account.gender case final gender?) ('Gender', gender.label),
      if (account.bloodGroup case final group?) ('Blood Group', group.label),
    ];

    return ProfileCard(
      children: [
        for (final (index, row) in rows.indexed)
          ProfileDetailRow(
            label: row.$1,
            value: row.$2,
            showDivider: index < rows.length - 1,
          ),
      ],
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
