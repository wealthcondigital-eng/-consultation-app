import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/document_viewer_screen.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../profile/presentation/widgets/profile_section.dart';
import '../widgets/add_certificate_sheet.dart';
import '../../domain/entities/doctor_credential.dart';
import '../../domain/entities/doctor_practice_profile.dart';
import '../controllers/doctor_credentials_controller.dart';

/// Credentials & Documents: what was filed, and what review made of it.
///
/// **No links to the files.** A doctor re-reading their own certificate is not
/// a flow this app has, and a URL that exists is a URL that leaks — the review
/// console mints one per view for a reviewer who needs it. What a doctor needs
/// is whether each document was accepted, and if not, the note saying what to
/// change. That is what is here.
class DoctorCredentialsScreen extends StatefulWidget {
  const DoctorCredentialsScreen({super.key});

  @override
  State<DoctorCredentialsScreen> createState() =>
      _DoctorCredentialsScreenState();
}

class _DoctorCredentialsScreenState extends State<DoctorCredentialsScreen> {
  late final DoctorCredentialsController _controller =
      sl<DoctorCredentialsController>();

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

  /// Back to the registration form, which is how a **registration** document is
  /// replaced.
  ///
  /// Replacing the degree certificate a reviewer objected to puts the whole
  /// application back through review, which is why it goes through the form
  /// rather than through an upload button here: a file swapped in place would
  /// leave the record approved against paperwork nobody had looked at.
  ///
  /// Adding a certificate is the opposite case and has its own button below —
  /// it is a new claim, reviewed on its own, and it does not re-open anything.
  void _refile() {
    Navigator.of(context).pushNamed(AppRoutes.doctorProfileSetup);
  }

  Future<void> _addCertificate() async {
    final added = await AddCertificateSheet.show(
      context,
      controller: _controller,
    );

    if (!mounted || !added) return;

    AppSnackBar.success(
      context,
      'Sent for review. It appears on your profile once it is accepted.',
    );
  }

  Future<void> _removeCertificate(DoctorCredential credential) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Remove this certificate?',
      message: tr(
        '“{title}” will be taken off your profile. '
        'You can add it again later.',
        {'title': tr(credential.displayTitle)},
      ),
      confirmLabel: 'Remove',
      cancelLabel: 'Keep it',
      icon: Icons.delete_outline_rounded,
      tone: AppConfirmTone.destructive,
    );

    if (!confirmed || !mounted) return;

    final removed = await _controller.removeCertificate(credential);
    if (!mounted) return;

    if (removed) {
      AppSnackBar.info(context, 'Certificate removed.');
      return;
    }

    AppSnackBar.error(
      context,
      _controller.errorMessage ?? 'That certificate could not be removed.',
    );
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
              title: 'Credentials',
              variant: AppTopBarVariant.outlined,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _Body(
                  controller: _controller,
                  onRefile: _refile,
                  onAddCertificate: _addCertificate,
                  onRemoveCertificate: _removeCertificate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.onRefile,
    required this.onAddCertificate,
    required this.onRemoveCertificate,
  });

  final DoctorCredentialsController controller;
  final VoidCallback onRefile;
  final VoidCallback onAddCertificate;
  final ValueChanged<DoctorCredential> onRemoveCertificate;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    final profile = controller.profile;
    if (profile == null) {
      return AppErrorView(
        message:
            controller.errorMessage ?? 'Your credentials are not available.',
        onRetry: controller.load,
      );
    }

    final credentials = controller.credentials;

    return AppRefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          sizing.screenPaddingH,
          sizing.spacingMd,
          sizing.screenPaddingH,
          sizing.spacingXxl,
        ),
        children: [
          _StatusCard(profile: profile),
          SizedBox(height: sizing.spacingLg),
          ProfileSection(
            title: 'Documents',
            child: credentials.isEmpty
                ? const AppEmptyState(
                    icon: Icons.description_outlined,
                    title: 'Nothing uploaded',
                    message:
                        'Your degree certificate is attached when you file '
                        'your registration.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final credential in credentials) ...[
                        if (credential != credentials.first)
                          SizedBox(height: sizing.spacingSm),
                        _CredentialCard(
                          credential: credential,
                          // Only their own additions. The registration's
                          // paperwork is what the approval rests on, and the
                          // API refuses to remove it either.
                          onRemove: credential.isRemovable
                              ? () => onRemoveCertificate(credential)
                              : null,
                        ),
                      ],
                    ],
                  ),
          ),
          SizedBox(height: sizing.spacingLg),
          // Available whatever the registration says. A doctor who has just
          // finished a fellowship should not have to wait for a review of
          // something else to record it, and adding one re-opens nothing:
          // it is a new claim, checked on its own.
          AppButton.outline(
            label: 'Add a certificate',
            leading: const Icon(Icons.add_rounded),
            onPressed: controller.isSaving ? null : onAddCertificate,
          ),
          SizedBox(height: sizing.spacingXs),
          Text(
            tr(
              'Fellowships, diplomas and specialist qualifications. Patients see '
              'one once a reviewer has accepted it.',
            ),
            style: sizing.text.caption,
            textAlign: TextAlign.center,
          ),
          if (profile.needsAttention) ...[
            SizedBox(height: sizing.spacingLg),
            AppButton.primary(label: 'Update and re-file', onPressed: onRefile),
          ],
          SizedBox(height: sizing.spacingLg),
          const _PrivacyNote(),
        ],
      ),
    );
  }
}

/// Where the registration stands, and what the reviewer said.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.profile});

  final DoctorPracticeProfile profile;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final (surface, border, tint, icon) = profile.isApproved
        ? (
            AppColors.badgeSurface,
            AppColors.successStrong,
            AppColors.success,
            Icons.verified_rounded,
          )
        : profile.needsAttention
        ? (
            AppColors.surfaceMuted,
            AppColors.danger,
            AppColors.danger,
            Icons.error_outline_rounded,
          )
        : (
            AppColors.infoSurface,
            AppColors.consultAccent.border,
            AppColors.primaryVivid,
            Icons.hourglass_top_rounded,
          );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(width: sizing.hairline, color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: sizing.iconSm, color: tint),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Text(
                  tr('Registration · {status}', {
                    'status': tr(profile.statusLabel),
                  }),
                  style: sizing.text.cardTitle.copyWith(color: tint),
                ),
              ),
            ],
          ),
          if (profile.registrationNumber case final number?) ...[
            SizedBox(height: sizing.spacingXs),
            Text(
              tr('Council registration {number}', {'number': number}),
              style: sizing.text.legalBody,
            ),
          ],
          // The reviewer's note, which for a rejection is the only thing that
          // tells the doctor what to do next.
          if (profile.rejectionReason case final reason?) ...[
            SizedBox(height: sizing.spacingSm),
            Text(
              reason,
              style: sizing.text.bodySmall.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

class _CredentialCard extends StatelessWidget {
  const _CredentialCard({required this.credential, this.onRemove});

  final DoctorCredential credential;

  /// Offered only on a certificate the doctor added themselves. Null on the
  /// registration's own paperwork, which the approval rests on.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final (badgeSurface, badgeText) = switch (credential.decision) {
      CredentialDecision.accepted => (
        AppColors.badgeSurface,
        AppColors.success,
      ),
      CredentialDecision.rejected => (AppColors.surfaceMuted, AppColors.danger),
      CredentialDecision.pending => (
        AppColors.primarySurface,
        AppColors.primaryDeep,
      ),
    };

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: sizing.iconChipSize * 0.75,
                height: sizing.iconChipSize * 0.75,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(sizing.radiusSm),
                ),
                child: Icon(
                  Icons.description_rounded,
                  size: sizing.iconSm,
                  color: AppColors.primaryVivid,
                ),
              ),
              SizedBox(width: sizing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The doctor's own words where there are any. The category
                    // — "Additional certificate" — tells them nothing they did
                    // not already know, and the title is the claim a reviewer
                    // is deciding on.
                    Text(
                      tr(credential.displayTitle),
                      style: sizing.text.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sizing.spacingXxs / 2),
                    Text(
                      credential.fileName,
                      style: sizing.text.cardSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sizing.spacingXxs),
                    Text(
                      '${credential.uploadedLabel} · ${credential.sizeLabel}',
                      style: sizing.text.metaLabel.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: sizing.spacingXs),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: sizing.spacingXs,
                  vertical: sizing.spacingXxs / 2,
                ),
                decoration: BoxDecoration(
                  color: badgeSurface,
                  borderRadius: BorderRadius.circular(sizing.radiusPill),
                ),
                child: Text(
                  tr(credential.decision.label),
                  style: sizing.text.badgeLabel.copyWith(
                    fontSize: sizing.sp(11),
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          if (credential.note case final note?) ...[
            SizedBox(height: sizing.spacingSm),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(sizing.spacingSm),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(sizing.radiusSm),
              ),
              child: Text(
                note,
                style: sizing.text.legalBody.copyWith(
                  color: credential.decision == CredentialDecision.rejected
                      ? AppColors.danger
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
          // What a pending certificate actually means for the doctor, said on
          // the card. "Awaiting review" alone leaves them wondering whether
          // patients can already see it; they cannot, and that is the point of
          // the queue.
          if (credential.type == CredentialType.certificate) ...[
            SizedBox(height: sizing.spacingXs),
            Text(
              tr(switch (credential.decision) {
                CredentialDecision.accepted => 'Shown on your public profile.',
                CredentialDecision.pending =>
                  'Visible only to you until a reviewer accepts it.',
                CredentialDecision.rejected =>
                  'Not shown to patients. Replace it to try again.',
              }),
              style: sizing.text.metaLabel.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          SizedBox(height: sizing.spacingXs),
          Row(
            children: [
              // Every document, whatever the decision was. A doctor whose
              // certificate was rejected over an illegible number cannot act
              // on that note without seeing the page it is about, and one who
              // filed two scans cannot otherwise tell which is which.
              TextButton.icon(
                onPressed: () => Navigator.of(context).pushNamed(
                  AppRoutes.documentViewer,
                  arguments: DocumentViewerArgs(
                    title: tr(credential.displayTitle),
                    subtitle: ' · ',
                    path: credential.filePath,
                  ),
                ),
                icon: Icon(Icons.visibility_outlined, size: sizing.iconXs),
                label: Text(tr('View'), style: sizing.text.sectionAction),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const Spacer(),
              if (onRemove case final onRemove?)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: Icon(Icons.delete_outline_rounded, size: sizing.iconXs),
                  label: Text(tr('Remove'), style: sizing.text.sectionAction),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

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
                Icons.shield_outlined,
                size: sizing.iconSm,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Text(
                  tr('Your documents'),
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
              'Uploaded files are not linked from this app. They are opened only '
              'by a reviewer, through a link created for that one view. To '
              'replace a document, file your registration again — the new file '
              'supersedes the old one and the application is reviewed afresh.',
            ),
            style: sizing.text.legalBody,
          ),
        ],
      ),
    );
  }
}
