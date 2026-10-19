import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../consultation/presentation/widgets/consultation_mode_sheet.dart'
    show iconForConsultationMode;

/// Confirms how the appointment will be taken. Pre-set to whatever the patient
/// chose on the way here, and changeable up to the moment they book.
class ConsultationTypePicker extends StatelessWidget {
  const ConsultationTypePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ConsultationMode selected;
  final ValueChanged<ConsultationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    // IntrinsicHeight gives the row a bounded height inside the scroll view,
    // which is what lets the cards stretch to match the taller of them.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final mode in ConsultationMode.values) ...[
            if (mode != ConsultationMode.values.first)
              SizedBox(width: sizing.spacingSm),
            Expanded(
              child: _TypeCard(
                mode: mode,
                isSelected: mode == selected,
                onTap: () => onChanged(mode),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final ConsultationMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusMd);

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? AppColors.primarySurface : AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: EdgeInsets.all(sizing.tilePadding),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                width: isSelected ? sizing.borderWidth : sizing.hairline,
                color: isSelected ? AppColors.primarySoft : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: sizing.avatarSize * 0.8,
                  height: sizing.avatarSize * 0.8,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryVivid
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(sizing.radiusSm),
                  ),
                  child: Icon(
                    iconForConsultationMode(mode),
                    size: sizing.iconXs,
                    color: isSelected
                        ? AppColors.surface
                        : AppColors.textSecondary,
                  ),
                ),
                SizedBox(width: sizing.spacingXs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(mode.callLabel),
                        style: sizing.text.cardTitle.copyWith(
                          color: isSelected
                              ? AppColors.primaryVivid
                              : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: sizing.spacingXxs * 0.5),
                      Text(
                        tr(mode.callNote),
                        style: sizing.text.cardSubtitle,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
