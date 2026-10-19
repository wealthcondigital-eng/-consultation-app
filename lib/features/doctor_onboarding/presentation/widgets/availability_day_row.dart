import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/doctor_availability.dart';
import '../../../../core/l10n/tr.dart';

/// The week as seven cells side by side, with the three selections a doctor
/// actually makes offered above it.
///
/// It used to be a `Wrap` of pill chips, which each stretched to the full width
/// of the page — seven rows and a scroll to get past a question that fits on
/// one line.
class AvailabilityDayRow extends StatelessWidget {
  const AvailabilityDayRow({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.onSelectAll,
  });

  final Set<Weekday> selected;
  final ValueChanged<Weekday> onToggle;

  /// Replaces the selection outright — the quick picks.
  final ValueChanged<Set<Weekday>> onSelectAll;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: sizing.spacingXs,
          runSpacing: sizing.spacingXxs,
          children: [
            _QuickPick(
              label: 'Weekdays',
              days: Weekday.workingWeek,
              selected: selected,
              onTap: onSelectAll,
            ),
            _QuickPick(
              label: 'Weekends',
              days: Weekday.weekend,
              selected: selected,
              onTap: onSelectAll,
            ),
            _QuickPick(
              label: 'Every day',
              days: Weekday.values.toSet(),
              selected: selected,
              onTap: onSelectAll,
            ),
          ],
        ),
        SizedBox(height: sizing.spacingSm),
        Row(
          children: [
            for (final day in Weekday.values) ...[
              if (day != Weekday.values.first) SizedBox(width: sizing.r(6)),
              Expanded(
                child: _DayCell(
                  day: day,
                  isSelected: selected.contains(day),
                  onTap: () => onToggle(day),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// One day. Equal width to its six neighbours, so the week reads as a week.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  final Weekday day;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusMd);

    return Semantics(
      button: true,
      selected: isSelected,
      label: tr(day.shortLabel),
      child: Material(
        color: isSelected ? AppColors.primaryDeep : AppColors.surfaceMuted,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            height: sizing.h(44),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: sizing.r(2)),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: isSelected
                  ? null
                  : Border.all(width: sizing.hairline, color: AppColors.border),
            ),
            // Seven cells across a 320pt phone leaves under 35pt each. Scaling
            // the label down beats clipping it to `Mo…`.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr(day.shortLabel),
                style: sizing.text.chipLabel.copyWith(
                  color: isSelected ? Colors.white : AppColors.textLabel,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `Weekdays`, `Weekends`, `Every day` — a whole selection in one tap.
class _QuickPick extends StatelessWidget {
  const _QuickPick({
    required this.label,
    required this.days,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Set<Weekday> days;
  final Set<Weekday> selected;
  final ValueChanged<Set<Weekday>> onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final isActive =
        selected.length == days.length && selected.containsAll(days);
    final radius = BorderRadius.circular(sizing.radiusPill);

    return Semantics(
      button: true,
      selected: isActive,
      child: Material(
        color: isActive ? AppColors.primarySurface : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: () => onTap(days),
          borderRadius: radius,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: sizing.spacingSm,
              vertical: sizing.spacingXxs + 1,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                width: sizing.hairline,
                color: isActive ? AppColors.primarySoft : AppColors.border,
              ),
            ),
            child: Text(
              tr(label),
              style: sizing.text.chipLabel.copyWith(
                fontSize: sizing.sp(11),
                color: isActive
                    ? AppColors.primaryDeep
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
