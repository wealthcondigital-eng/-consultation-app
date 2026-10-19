import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../doctors/domain/entities/speciality.dart';
import '../../../../core/l10n/tr.dart';

/// Maps a domain symbol to its glyph, so the entity stays free of Flutter
/// types and an unknown speciality still renders.
IconData iconForSpeciality(SpecialitySymbol symbol) => switch (symbol) {
  SpecialitySymbol.general => Icons.person_search_rounded,
  SpecialitySymbol.dentistry => Icons.medication_liquid_rounded,
  SpecialitySymbol.cardiology => Icons.favorite_rounded,
  SpecialitySymbol.paediatrics => Icons.child_care_rounded,
  SpecialitySymbol.dermatology => Icons.spa_rounded,
  SpecialitySymbol.neurology => Icons.psychology_rounded,
  SpecialitySymbol.other => Icons.local_hospital_rounded,
};

/// One speciality in the grid: a glyph circle above its name.
class SpecialityTile extends StatelessWidget {
  const SpecialityTile({
    super.key,
    required this.speciality,
    required this.onTap,
  });

  final Speciality speciality;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusMd);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(sizing.tilePadding),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(width: sizing.hairline, color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: sizing.avatarSize,
                height: sizing.avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconForSpeciality(speciality.symbol),
                  size: sizing.iconLg,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: sizing.spacingXs),
              Text(
                tr(speciality.name),
                style: sizing.text.tileLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
