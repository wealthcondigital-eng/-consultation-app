import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/schedule_day.dart';

/// The row of bookable days. Scrolls horizontally so a longer booking window
/// does not have to squeeze more cards into the same width.
class ScheduleDateStrip extends StatelessWidget {
  const ScheduleDateStrip({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onDaySelected,
  });

  final List<ScheduleDay> days;
  final int selectedIndex;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < days.length; index++) ...[
            if (index > 0) SizedBox(width: sizing.spacingXs),
            _DayCard(
              day: days[index],
              isSelected: index == selectedIndex,
              onTap: () => onDaySelected(index),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  final ScheduleDay day;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusMd);
    final isBookable = day.hasOpenSlots;

    return Semantics(
      button: true,
      selected: isSelected,
      label: day.dateLabel,
      child: Opacity(
        opacity: isBookable ? 1 : 0.4,
        child: Material(
          color: isSelected ? AppColors.primaryVivid : AppColors.surface,
          borderRadius: radius,
          child: InkWell(
            onTap: isBookable ? onTap : null,
            borderRadius: radius,
            child: Container(
              width: sizing.w(58),
              padding: EdgeInsets.symmetric(vertical: sizing.spacingSm),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  width: sizing.hairline,
                  color: isSelected ? AppColors.primaryVivid : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.weekdayLabel,
                    style: sizing.text.inputLabel.copyWith(
                      color: isSelected
                          ? AppColors.primarySurface
                          : AppColors.textTertiary,
                    ),
                  ),
                  SizedBox(height: sizing.spacingXxs),
                  Text(
                    day.dayLabel,
                    style: sizing.text.navTitle.copyWith(
                      color: isSelected
                          ? AppColors.surface
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (day.isToday) ...[
                    SizedBox(height: sizing.spacingXxs * 0.5),
                    Text(
                      tr('TODAY'),
                      style: sizing.text.inputLabel.copyWith(
                        fontSize: sizing.sp(9),
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.surface
                            : AppColors.primaryVivid,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
