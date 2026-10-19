import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/medical_history.dart';

/// The patient's medical records at a glance, with a way in.
///
/// Records first: prescriptions, lab reports and scans. The typed lists of
/// conditions, medication and allergies it used to summarise are gone — a
/// doctor reads the prescription, and a patient's own paraphrase of it was the
/// part of the profile nobody finished.
class MedicalHistoryCard extends StatelessWidget {
  const MedicalHistoryCard({
    super.key,
    required this.history,
    required this.onEdit,
  });

  /// Only its note is shown, when there is one.
  final MedicalHistory history;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final note = history.notes?.trim();
    final radius = BorderRadius.circular(sizing.radiusLg);

    return Material(
      color: AppColors.infoSurface,
      borderRadius: radius,
      child: InkWell(
        onTap: onEdit,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(sizing.cardPadding),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              width: sizing.hairline,
              color: AppColors.consultAccent.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: sizing.r(40),
                    height: sizing.r(40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryVivid,
                      borderRadius: BorderRadius.circular(sizing.radiusMd),
                    ),
                    child: Icon(
                      Icons.folder_shared_rounded,
                      size: sizing.iconMd,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: sizing.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Medical records'),
                          style: sizing.text.cardTitle.copyWith(
                            color: AppColors.primaryDeep,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          tr('Prescriptions, lab reports & scans'),
                          style: sizing.text.cardSubtitle,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primaryVivid,
                    size: sizing.iconMd,
                  ),
                ],
              ),
              SizedBox(height: sizing.spacingSm),
              Wrap(
                spacing: sizing.spacingXs,
                runSpacing: sizing.spacingXxs,
                children: const [
                  _Pill(
                    icon: Icons.description_outlined,
                    label: 'Prescriptions',
                  ),
                  _Pill(icon: Icons.science_outlined, label: 'Lab reports'),
                  _Pill(icon: Icons.image_outlined, label: 'Scans'),
                ],
              ),
              if (note != null && note.isNotEmpty) ...[
                SizedBox(height: sizing.spacingSm),
                Text(
                  tr('Note: {note}', {'note': note}),
                  style: sizing.text.legalBody,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: sizing.spacingSm),
              Text(
                tr('Shared only with the doctor you consult.'),
                style: sizing.text.metaLabel.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingXs,
        vertical: sizing.spacingXxs / 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: sizing.sp(12), color: AppColors.primaryDeep),
          SizedBox(width: sizing.spacingXxs),
          Text(
            tr(label),
            style: sizing.text.badgeLabel.copyWith(
              fontSize: sizing.sp(11),
              color: AppColors.primaryDeep,
            ),
          ),
        ],
      ),
    );
  }
}
