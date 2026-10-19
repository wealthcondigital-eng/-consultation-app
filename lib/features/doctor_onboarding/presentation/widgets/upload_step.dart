import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/medical_certificate.dart';
import '../controllers/doctor_setup_controller.dart';
import 'certificate_upload_card.dart';
import 'onboarding_banner.dart';
import '../../../../core/l10n/tr.dart';

/// Step one: hand over the medical certificate.
///
/// **Required, not offered.** This step used to carry a Skip in the app bar and
/// the details behind it could be typed by hand, so a registration could be
/// filed — and a doctor account opened — with no document a reviewer had ever
/// seen. The upload is the registration: without it there is nothing to
/// approve, so there is nothing to skip to.
class UploadStep extends StatelessWidget {
  const UploadStep({
    super.key,
    required this.controller,
    required this.onPick,
    required this.onContinue,
  });

  final DoctorSetupController controller;

  /// Asks for a file from [source]. The picker itself lives in the screen.
  final ValueChanged<CertificateSource> onPick;

  /// Moves to the details step. Enabled only once a file has been read.
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final hasCertificate = controller.hasCertificate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CertificateUploadCard(
          certificate: controller.certificate,
          isParsing: controller.isParsing,
          // A required field that has not been filled in and has just been
          // asked for. The card outlines itself in red rather than leaving a
          // snackbar as the only sign of what is wrong.
          hasError: controller.showErrors && !hasCertificate,
          onTap: () => onPick(CertificateSource.gallery),
          onRemove: controller.clearCertificate,
        ),
        SizedBox(height: sizing.spacingXl),
        OnboardingBanner(
          icon: hasCertificate
              ? Icons.verified_rounded
              : Icons.auto_awesome_rounded,
          message: hasCertificate
              ? 'Certificate received. We have filled in what we could read '
                    'from it — check the details on the next step.'
              : 'Upload your medical certificate as a PDF or a photo. Our AI '
                    'reads it and fills in your profile, and a reviewer checks '
                    'it before your account goes live.',
        ),
        SizedBox(height: sizing.spacingXxl),
        AppButton.emphasis(
          label: hasCertificate ? 'Replace with a Scan' : 'Scan Document',
          leading: Icon(
            Icons.photo_camera_rounded,
            size: sizing.iconLg,
            color: Colors.white,
          ),
          isLoading: controller.isParsing,
          onPressed: () => onPick(CertificateSource.scan),
        ),
        SizedBox(height: sizing.spacingSm),
        AppButton.outline(
          label: hasCertificate
              ? 'Choose a Different File'
              : 'Upload PDF or Image',
          leading: Icon(
            Icons.folder_open_rounded,
            size: sizing.iconLg,
            color: AppColors.textPrimary,
          ),
          onPressed: controller.isParsing
              ? null
              : () => onPick(CertificateSource.gallery),
        ),
        SizedBox(height: sizing.spacingXl),
        // Present from the start rather than appearing once a file lands, so
        // the way forward is visible and it is obvious what unlocks it.
        AppButton.primary(
          label: 'Continue',
          onPressed: hasCertificate && !controller.isParsing
              ? onContinue
              : null,
        ),
        if (!hasCertificate) ...[
          SizedBox(height: sizing.spacingXs),
          Text(
            tr('A medical certificate is required to register as a doctor.'),
            textAlign: TextAlign.center,
            style: sizing.text.metaLabel.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}
