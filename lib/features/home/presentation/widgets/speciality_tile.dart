import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../doctors/domain/entities/speciality.dart';
import '../../../../core/l10n/tr.dart';

/// A speciality's picture — a heart for cardiology, a tooth for dentistry —
/// so a patient finds theirs by looking rather than reading.
///
/// Drawn from `assets/specialities/`: one SVG per [SpecialitySymbol], each on
/// its own soft colour, so they stay sharp at any size and need no network.
/// An unknown speciality gets the neutral medical one.
class SpecialityArt extends StatelessWidget {
  const SpecialityArt({
    super.key,
    required this.symbol,
    required this.size,
    this.semanticLabel,
  });

  final SpecialitySymbol symbol;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/specialities/${symbol.assetName}.svg',
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
    );
  }
}

/// One speciality in the grid: its picture above its name.
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
              SpecialityArt(
                symbol: speciality.symbol,
                size: sizing.r(52),
                semanticLabel: tr(speciality.name),
              ),
              SizedBox(height: sizing.spacingXs),
              Text(
                tr(speciality.name),
                style: sizing.text.tileLabel,
                textAlign: TextAlign.center,
                // Two lines, so a long name wraps instead of being cut.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
