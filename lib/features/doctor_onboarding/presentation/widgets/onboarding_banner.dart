import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/l10n/tr.dart';

/// A tinted note in the setup flow — what the AI will do with an upload, or
/// that the details below came back verified.
class OnboardingBanner extends StatelessWidget {
  const OnboardingBanner({
    super.key,
    required this.icon,
    required this.message,
    this.foreground,
  });

  final IconData icon;
  final String message;

  /// Icon and text colour. The fill is the same soft green either way, so the
  /// two banners read as one family.
  /// Defaults to [AppColors.primaryDeep].
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.badgeSurface,
        borderRadius: BorderRadius.circular(sizing.radiusMd + 2),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: sizing.iconSm,
            color: foreground ?? AppColors.primaryDeep,
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Text(
              tr(message),
              style: sizing.text.fieldLabel.copyWith(
                color: foreground ?? AppColors.primaryDeep,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
