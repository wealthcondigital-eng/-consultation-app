import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/hero_sheet_page.dart';
import '../../domain/entities/user_role.dart';
import '../controllers/landing_controller.dart';
import '../../../../core/l10n/tr.dart';

/// The role choice and trust line — the white sheet of the landing screen.
class RoleActions extends StatelessWidget {
  const RoleActions({
    super.key,
    required this.controller,
    required this.onRoleSelected,
  });

  final LandingController controller;
  final ValueChanged<UserRole> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return HeroSheet(
          footer: Text(
            tr('Trusted by doctors. Loved by patients.'),
            textAlign: TextAlign.center,
            style: sizing.text.caption,
          ),
          children: [
            Text(
              tr('Choose how you want to continue'),
              textAlign: TextAlign.center,
              style: sizing.text.helperText.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: sizing.spacingMd),
            AppButton.primary(
              label: tr('Continue as Patient'),
              isLoading: controller.isPending(UserRole.patient),
              onPressed: controller.isBusy
                  ? null
                  : () => onRoleSelected(UserRole.patient),
            ),
            SizedBox(height: sizing.spacingSm),
            AppButton.secondary(
              label: tr('Continue as Doctor'),
              isLoading: controller.isPending(UserRole.doctor),
              onPressed: controller.isBusy
                  ? null
                  : () => onRoleSelected(UserRole.doctor),
            ),
          ],
        );
      },
    );
  }
}
