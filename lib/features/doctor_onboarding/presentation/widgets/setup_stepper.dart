import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/doctor_setup_step.dart';
import '../../../../core/l10n/tr.dart';

/// The three-step progress header: a numbered badge per step, ticked once it is
/// behind the doctor.
class SetupStepper extends StatelessWidget {
  const SetupStepper({super.key, required this.current, required this.isDone});

  final DoctorSetupStep current;

  /// Whether a step has already been completed.
  final bool Function(DoctorSetupStep step) isDone;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: sizing.screenPaddingH,
        vertical: sizing.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final step in DoctorSetupStep.values) ...[
            Flexible(
              child: _Step(
                step: step,
                isCurrent: step == current,
                isDone: isDone(step),
              ),
            ),
            if (step != DoctorSetupStep.values.last)
              Icon(
                Icons.chevron_right_rounded,
                size: sizing.iconXs,
                color: AppColors.textTertiary,
              ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.step,
    required this.isCurrent,
    required this.isDone,
  });

  final DoctorSetupStep step;
  final bool isCurrent;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final isActive = isCurrent || isDone;
    final badgeSize = sizing.iconMd;

    return Semantics(
      label: tr('Step {n} of {total}: {label}', {
        'n': step.number,
        'total': DoctorSetupStep.values.length,
        'label': tr(step.label),
      }),
      selected: isCurrent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: badgeSize,
            height: badgeSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryDeep : AppColors.border,
              shape: BoxShape.circle,
            ),
            child: isDone
                ? Icon(
                    Icons.check_rounded,
                    size: sizing.iconXs * 0.8,
                    color: Colors.white,
                  )
                : Text(
                    '${step.number}',
                    style: sizing.text.badgeLabel.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
          ),
          SizedBox(width: sizing.spacingXs),
          Flexible(
            child: Text(
              tr(step.label),
              style: sizing.text.fieldLabel.copyWith(
                color: isActive
                    ? AppColors.primaryDeep
                    : AppColors.textTertiary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
