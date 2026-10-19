import 'package:flutter/material.dart';

import '../../../../core/push/ring_readiness_probe.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../controllers/ring_readiness_controller.dart';
import '../../../../core/l10n/tr.dart';

/// "Calls may not ring when the app is closed" — shown under the presence dial
/// while the doctor is Online and the phone is holding calls back.
///
/// A warning rather than a gate: the doctor is still Online and still gets
/// every call while the app is open. What they lose is the ring once it is
/// closed, and they deserve to know that before a patient finds out for them.
class RingSetupCard extends StatelessWidget {
  const RingSetupCard({
    super.key,
    required this.missingCount,
    required this.onTap,
  });

  final int missingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Material(
      color: AppColors.warningSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        side: BorderSide(
          width: sizing.hairline,
          color: AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(sizing.tilePadding),
          child: Row(
            children: [
              Icon(
                Icons.notifications_off_rounded,
                size: sizing.iconSm,
                color: AppColors.warning,
              ),
              SizedBox(width: sizing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Calls may not ring when the app is closed'),
                      style: sizing.text.cardTitle,
                    ),
                    SizedBox(height: sizing.spacingXxs * 0.5),
                    Text(
                      missingCount == 1
                          ? tr('1 setting to fix on this phone')
                          : tr('{count} settings to fix on this phone', {
                              'count': missingCount,
                            }),
                      style: sizing.text.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(width: sizing.spacingXs),
              Text(
                tr('Fix'),
                style: sizing.text.metaLabel.copyWith(
                  color: AppColors.primaryDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: sizing.iconSm,
                color: AppColors.primaryDeep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The checklist: each setting, whether it is right, and the way to fix it.
class RingSetupSheet extends StatelessWidget {
  const RingSetupSheet({super.key, required this.controller});

  final RingReadinessController controller;

  static Future<void> show(
    BuildContext context, {
    required RingReadinessController controller,
  }) {
    final sizing = context.sizing;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        maxWidth: sizing.w(560),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(sizing.radiusLg),
        ),
      ),
      builder: (_) => RingSetupSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(
              sizing.screenPaddingH,
              0,
              sizing.screenPaddingH,
              sizing.spacingLg,
            ),
            children: [
              Text(tr('Make sure calls ring'), style: sizing.text.headline),
              SizedBox(height: sizing.spacingXs),
              Text(
                tr(
                  'When the app is closed, your phone decides whether a '
                  'patient’s call can ring. These settings let it.',
                ),
                style: sizing.text.bodySmall,
              ),
              SizedBox(height: sizing.spacingMd),
              for (final check in controller.checks) ...[
                _CheckRow(
                  check: check,
                  onFix: () => controller.fix(check.kind),
                  onConfirm: check.kind == RingCheckKind.autostart
                      ? controller.confirmAutostart
                      : null,
                ),
                SizedBox(height: sizing.spacingSm),
              ],
              if (controller.isReady) ...[
                SizedBox(height: sizing.spacingXs),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: sizing.iconSm,
                      color: AppColors.success,
                    ),
                    SizedBox(width: sizing.spacingXs),
                    Expanded(
                      child: Text(
                        tr(
                          'All set. Calls will ring even with the app closed.',
                        ),
                        style: sizing.text.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: sizing.spacingMd),
                AppButton.primary(
                  label: 'Done',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check, required this.onFix, this.onConfirm});

  final RingCheck check;
  final VoidCallback onFix;

  /// Only for auto-start, which the phone cannot report back.
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final ok = check.isSatisfied;

    return Container(
      padding: EdgeInsets.all(sizing.tilePadding),
      decoration: BoxDecoration(
        color: ok ? AppColors.successSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusMd),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: sizing.iconSm,
                color: ok ? AppColors.success : AppColors.warning,
              ),
              SizedBox(width: sizing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(check.title), style: sizing.text.cardTitle),
                    if (!ok) ...[
                      SizedBox(height: sizing.spacingXxs * 0.5),
                      Text(tr(check.description), style: sizing.text.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!ok) ...[
            SizedBox(height: sizing.spacingSm),
            Row(
              children: [
                Expanded(
                  child: AppButton.primary(
                    label: check.actionLabel,
                    size: AppButtonSize.compact,
                    onPressed: onFix,
                  ),
                ),
                if (onConfirm != null) ...[
                  SizedBox(width: sizing.spacingXs),
                  Expanded(
                    child: AppButton.outline(
                      label: 'I’ve allowed it',
                      size: AppButtonSize.compact,
                      onPressed: onConfirm,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
