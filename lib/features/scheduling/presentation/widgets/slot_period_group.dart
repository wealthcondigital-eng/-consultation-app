import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/time_slot.dart';

/// Maps a period to its glyph, keeping Flutter types out of the domain enum.
IconData iconForSlotPeriod(SlotPeriod period) => switch (period) {
  SlotPeriod.morning => Icons.wb_sunny_outlined,
  SlotPeriod.afternoon => Icons.wb_twilight_rounded,
  SlotPeriod.evening => Icons.nights_stay_outlined,
};

/// One half of the day: its heading, then the times it offers.
class SlotPeriodGroup extends StatelessWidget {
  const SlotPeriodGroup({
    super.key,
    required this.period,
    required this.slots,
    required this.selectedSlot,
    required this.onSlotSelected,
  });

  final SlotPeriod period;
  final List<TimeSlot> slots;
  final TimeSlot? selectedSlot;
  final ValueChanged<TimeSlot> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              iconForSlotPeriod(period),
              size: sizing.iconXs,
              color: AppColors.textSecondary,
            ),
            SizedBox(width: sizing.spacingXxs * 1.5),
            Text(
              tr(period.label),
              style: sizing.text.helperText.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: sizing.spacingXs),
        Wrap(
          spacing: sizing.w(8),
          runSpacing: sizing.spacingXs,
          children: [
            for (final slot in slots)
              _SlotChip(
                slot: slot,
                isSelected: slot == selectedSlot,
                onTap: () => onSlotSelected(slot),
              ),
          ],
        ),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  final TimeSlot slot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusSm);

    final background = switch ((isSelected, slot.isAvailable)) {
      (true, _) => AppColors.primaryVivid,
      // A taken slot keeps its place on the grid, filled and greyed out.
      (false, false) => AppColors.border,
      (false, true) => AppColors.surface,
    };
    final labelColor = switch ((isSelected, slot.isAvailable)) {
      (true, _) => AppColors.surface,
      (false, false) => AppColors.textTertiary,
      (false, true) => AppColors.textPrimary,
    };

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: slot.isAvailable,
      label: slot.timeLabel,
      child: Opacity(
        opacity: slot.isAvailable ? 1 : 0.4,
        child: Material(
          color: background,
          borderRadius: radius,
          child: InkWell(
            onTap: slot.isAvailable ? onTap : null,
            borderRadius: radius,
            child: Container(
              width: sizing.w(78),
              padding: EdgeInsets.symmetric(vertical: sizing.spacingXs * 1.25),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  width: sizing.hairline,
                  color: isSelected ? AppColors.primaryVivid : AppColors.border,
                ),
              ),
              child: Text(
                slot.label,
                style: sizing.text.chipLabel.copyWith(color: labelColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
