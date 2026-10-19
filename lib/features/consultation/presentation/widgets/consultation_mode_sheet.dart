import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/consultation_mode.dart';

/// Maps a mode to its glyph, keeping Flutter types out of the domain enum.
IconData iconForConsultationMode(ConsultationMode mode) => switch (mode) {
  ConsultationMode.video => Icons.videocam_rounded,
  ConsultationMode.audio => Icons.call_rounded,
};

/// Asks how the patient wants to meet the doctor, with each mode's price.
///
/// Returns the chosen [ConsultationMode], or null if dismissed.
class ConsultationModeSheet extends StatelessWidget {
  const ConsultationModeSheet({super.key, this.doctor});

  /// Omit the doctor when the patient chooses a mode before browsing doctors.
  final Doctor? doctor;

  static Future<ConsultationMode?> show(
    BuildContext context, {
    Doctor? doctor,
  }) {
    return showModalBottomSheet<ConsultationMode>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sizing.radiusXl),
        ),
      ),
      builder: (_) => ConsultationModeSheet(doctor: doctor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          sizing.screenPaddingH,
          0,
          sizing.screenPaddingH,
          sizing.spacingXl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('How would you like to consult?'),
              style: sizing.text.listTitle,
            ),
            SizedBox(height: sizing.spacingXxs),
            Text(
              doctor == null
                  ? tr('Choose a call type before selecting your doctor.')
                  : tr('with {name}', {'name': doctor!.name}),
              style: sizing.text.bodySmall,
            ),
            SizedBox(height: sizing.spacingMd),
            for (final mode in ConsultationMode.values) ...[
              if (mode != ConsultationMode.values.first)
                SizedBox(height: sizing.spacingSm),
              _ModeOption(
                mode: mode,
                price: switch (doctor) {
                  final doctor? => doctor.formatFee(doctor.feeFor(mode)),
                  null => null,
                },
                onTap: () => Navigator.of(context).pop(mode),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.price,
    required this.onTap,
  });

  final ConsultationMode mode;

  /// Fee for this mode, or null before a doctor is chosen and pricing is known.
  final String? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusLg);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(sizing.cardPadding),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(width: sizing.hairline, color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: sizing.iconChipSize,
                height: sizing.iconChipSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(sizing.radiusMd),
                ),
                child: Icon(
                  iconForConsultationMode(mode),
                  size: sizing.iconMd,
                  color: AppColors.primaryVivid,
                ),
              ),
              SizedBox(width: sizing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(mode.label), style: sizing.text.cardTitle),
                    SizedBox(height: sizing.spacingXxs * 0.5),
                    Text(tr(mode.description), style: sizing.text.cardSubtitle),
                  ],
                ),
              ),
              SizedBox(width: sizing.spacingXs),
              if (price case final price?)
                Text(price, style: sizing.text.listTitle)
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: sizing.iconMd,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
