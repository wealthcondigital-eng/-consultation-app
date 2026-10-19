import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/medical_certificate.dart';
import '../../../../core/l10n/tr.dart';

/// The drop target for the medical certificate: an invitation before a file is
/// chosen, the file's name once one is, and a spinner while it is being read.
class CertificateUploadCard extends StatelessWidget {
  const CertificateUploadCard({
    super.key,
    required this.certificate,
    required this.isParsing,
    required this.onTap,
    required this.onRemove,
    this.hasError = false,
  });

  final MedicalCertificate? certificate;

  /// True while the AI is reading the file.
  final bool isParsing;

  /// True once Continue has been pressed with nothing uploaded. The card is
  /// the only control on the step, so it has to carry the validation itself —
  /// there is no field below it to turn red.
  final bool hasError;

  final VoidCallback onTap;

  /// Drops the chosen file so another can be picked.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusXl);
    final file = certificate;

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: isParsing ? null : onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          height: sizing.h(200),
          padding: EdgeInsets.all(sizing.cardPadding),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              width: hasError ? sizing.borderWidth : sizing.hairline,
              color: switch ((hasError, file)) {
                (true, null) => AppColors.danger,
                (_, null) => AppColors.primary,
                _ => AppColors.success,
              },
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Glyph(
                isParsing: isParsing,
                hasFile: file != null,
                hasError: hasError && file == null,
              ),
              SizedBox(height: sizing.spacingSm),
              Text(
                switch ((isParsing, file)) {
                  (true, _) => tr('Reading your certificate…'),
                  (false, final file?) => file.fileName,
                  (false, null) => tr('Upload Medical Certificate'),
                },
                style: sizing.text.listTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: sizing.spacingXxs),
              Text(
                switch ((isParsing, file)) {
                  (true, _) => tr('This only takes a moment'),
                  (false, final file?) => tr('{size} • Tap to replace', {
                    'size': file.sizeLabel,
                  }),
                  (false, null) => tr('Supports PDF, JPG or PNG up to {mb}MB', {
                    'mb': MedicalCertificate.maxSizeBytes ~/ (1024 * 1024),
                  }),
                },
                style: sizing.text.cardSubtitle.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              if (file != null && !isParsing) ...[
                SizedBox(height: sizing.spacingXs),
                TextButton(
                  onPressed: onRemove,
                  child: Text(
                    tr('Remove'),
                    style: sizing.text.sectionAction.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({
    required this.isParsing,
    required this.hasFile,
    this.hasError = false,
  });

  final bool isParsing;
  final bool hasFile;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final size = sizing.r(56);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: switch ((hasError, hasFile)) {
          (true, false) => AppColors.dangerSurface,
          (_, true) => AppColors.badgeSurface,
          _ => AppColors.primarySurface,
        },
        shape: BoxShape.circle,
      ),
      child: isParsing
          ? SizedBox.square(
              dimension: sizing.iconMd,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.success),
              ),
            )
          : Icon(
              hasFile ? Icons.description_rounded : Icons.cloud_upload_outlined,
              size: sizing.iconMd,
              color: switch ((hasError, hasFile)) {
                (true, false) => AppColors.danger,
                (_, true) => AppColors.success,
                _ => AppColors.primary,
              },
            ),
    );
  }
}
