import 'package:flutter/material.dart';

import '../../../../core/branding/app_brand.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/l10n/tr.dart';

/// Logo badge, wordmark and tagline — the gradient half of the landing screen.
///
/// Centred on its own axis and given the spare height of the page, because on
/// the landing screen the brand is the content: the two buttons below it are
/// one decision, and padding them out to fill a phone only moved them away from
/// the thumb. It carries straight on from the splash, which shows the same
/// lockup on the same gradient a moment earlier.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final text = sizing.text;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.screenPaddingH,
        vertical: sizing.spacingXxl,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogoMark(
              size: sizing.brandMarkSizeHero,
              color: AppColors.onBrand,
            ),
            SizedBox(height: sizing.spacingXl),
            Text(
              AppBrand.name,
              style: text.brandTitle.copyWith(color: AppColors.onBrand),
            ),
            SizedBox(height: sizing.spacingXs),
            Text(
              tr(AppBrand.tagline),
              style: text.brandTagline.copyWith(color: AppColors.onBrandMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
