import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';

/// The reassurance banner at the top of the anonymous booking form.
class PrivacyNotice extends StatelessWidget {
  const PrivacyNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.tilePadding),
      decoration: BoxDecoration(
        color: AppColors.badgeSurface,
        borderRadius: BorderRadius.circular(sizing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: sizing.iconLg,
            color: AppColors.primaryDeep,
          ),
          SizedBox(width: sizing.spacingXs),
          Expanded(
            child: Text(
              tr(message),
              style: sizing.text.fieldLabel.copyWith(
                color: AppColors.primaryDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The shield in the corner of the anonymous screens' top bar — a standing
/// marker that this part of the app hides who you are.
class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      label: tr('Private consultation'),
      child: Container(
        width: sizing.iconButtonSize,
        height: sizing.iconButtonSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.badgeSurface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.shield_outlined,
          size: sizing.iconLg,
          color: AppColors.success,
        ),
      ),
    );
  }
}
