import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/consult_option.dart';

/// A consultation option: glyph, title, supporting line, copy and one action.
class ConsultOptionCard extends StatelessWidget {
  const ConsultOptionCard({
    super.key,
    required this.option,
    required this.onAction,
    this.isBusy = false,
  });

  final ConsultOption option;
  final VoidCallback onAction;
  final bool isBusy;

  bool get _isInstant => option.kind == ConsultOptionKind.instant;

  IconData get _icon =>
      _isInstant ? Icons.monitor_heart_rounded : Icons.calendar_month_rounded;

  Color get _glyphSurface =>
      _isInstant ? AppColors.successSurface : AppColors.primarySurface;

  Color get _glyphColor =>
      _isInstant ? AppColors.success : AppColors.primaryVivid;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final waitLabel = option.estimatedWaitLabel;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPaddingLarge),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusXl),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: sizing.iconChipSize,
                height: sizing.iconChipSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _glyphSurface,
                  borderRadius: BorderRadius.circular(sizing.radiusMd),
                ),
                child: Icon(_icon, size: sizing.iconMd, color: _glyphColor),
              ),
              SizedBox(width: sizing.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(option.title), style: sizing.text.cardTitleLarge),
                    if (waitLabel != null) ...[
                      SizedBox(height: sizing.spacingXxs),
                      _WaitBadge(label: waitLabel),
                    ] else if (option.note != null) ...[
                      SizedBox(height: sizing.spacingXxs),
                      Text(tr(option.note!), style: sizing.text.cardNote),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: sizing.spacingMd),
          Text(tr(option.description), style: sizing.text.cardBody),
          SizedBox(height: sizing.spacingMd),
          // The instant option is the screen's headline action; scheduling is
          // the calmer alternative beside it.
          if (_isInstant)
            AppButton.emphasis(
              label: option.actionLabel,
              isLoading: isBusy,
              onPressed: option.isAvailable ? onAction : null,
            )
          else
            AppButton.outline(
              label: option.actionLabel,
              isLoading: isBusy,
              onPressed: option.isAvailable ? onAction : null,
            ),
        ],
      ),
    );
  }
}

class _WaitBadge extends StatelessWidget {
  const _WaitBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingXs,
        vertical: sizing.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.badgeSurface,
        borderRadius: BorderRadius.circular(sizing.radiusXs + 2),
      ),
      child: Text(
        label,
        // The design pairs a green pill with the deep blue label.
        style: sizing.text.badgeLabel.copyWith(color: AppColors.primaryDeep),
      ),
    );
  }
}
