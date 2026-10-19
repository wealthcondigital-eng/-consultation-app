import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/doctor_availability.dart';
import '../../../../core/l10n/tr.dart';

/// The hourly windows, grouped by part of day, plus whatever the doctor added
/// by hand.
///
/// The presets used to be one eight-chip block with no ordering cue in it. They
/// are the same eight windows; the headings are what make them findable.
class AvailabilitySlotPicker extends StatelessWidget {
  const AvailabilitySlotPicker({
    super.key,
    required this.presets,
    required this.customSlots,
    required this.selected,
    required this.onToggle,
    required this.onRemoveCustom,
  });

  final List<AvailabilitySlot> presets;
  final List<AvailabilitySlot> customSlots;
  final Set<AvailabilitySlot> selected;
  final ValueChanged<AvailabilitySlot> onToggle;
  final ValueChanged<AvailabilitySlot> onRemoveCustom;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final groups = <DayPart, List<AvailabilitySlot>>{};
    for (final slot in presets) {
      groups.putIfAbsent(slot.partOfDay, () => []).add(slot);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final part in DayPart.values)
          if (groups[part] case final slots? when slots.isNotEmpty) ...[
            if (part != DayPart.values.first)
              SizedBox(height: sizing.spacingMd),
            _GroupLabel(text: tr(part.label)),
            SizedBox(height: sizing.spacingXs),
            _ChipGrid(slots: slots, selected: selected, onToggle: onToggle),
          ],
        if (customSlots.isNotEmpty) ...[
          SizedBox(height: sizing.spacingMd),
          _GroupLabel(text: tr('Your own')),
          SizedBox(height: sizing.spacingXs),
          // Full width rather than two across: these carry a remove control,
          // and there is rarely more than a couple of them.
          for (final slot in customSlots) ...[
            if (slot != customSlots.first) SizedBox(height: sizing.spacingXs),
            _CustomSlotRow(
              slot: slot,
              isSelected: selected.contains(slot),
              onToggle: () => onToggle(slot),
              onRemove: () => onRemoveCustom(slot),
            ),
          ],
        ],
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Text(
      text.toUpperCase(),
      style: sizing.text.metaLabel.copyWith(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// Two chips across, one on a screen too narrow for two.
class _ChipGrid extends StatelessWidget {
  const _ChipGrid({
    required this.slots,
    required this.selected,
    required this.onToggle,
  });

  final List<AvailabilitySlot> slots;
  final Set<AvailabilitySlot> selected;
  final ValueChanged<AvailabilitySlot> onToggle;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < sizing.w(280) ? 1 : 2;
        final gap = sizing.spacingXs;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final slot in slots)
              SizedBox(
                width: width,
                child: SlotChip(
                  label: slot.compactLabel,
                  isSelected: selected.contains(slot),
                  onTap: () => onToggle(slot),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One selectable window.
class SlotChip extends StatelessWidget {
  const SlotChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusMd);

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? AppColors.primaryDeep : AppColors.surfaceMuted,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            height: sizing.h(42),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: sizing.spacingXs),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: isSelected
                  ? null
                  : Border.all(width: sizing.hairline, color: AppColors.border),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
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

/// A hand-entered window: selectable like a preset, and removable unlike one.
class _CustomSlotRow extends StatelessWidget {
  const _CustomSlotRow({
    required this.slot,
    required this.isSelected,
    required this.onToggle,
    required this.onRemove,
  });

  final AvailabilitySlot slot;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusMd);

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryDeep : AppColors.surfaceMuted,
        borderRadius: radius,
        border: isSelected
            ? null
            : Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              child: InkWell(
                onTap: onToggle,
                borderRadius: radius,
                child: Container(
                  height: sizing.h(42),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(horizontal: sizing.spacingSm),
                  child: Text(
                    slot.label,
                    style: sizing.text.chipLabel.copyWith(
                      color: isSelected ? Colors.white : AppColors.textLabel,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: tr('Remove {slot}', {'slot': slot.label}),
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: sizing.spacingSm),
                child: Icon(
                  Icons.close_rounded,
                  size: sizing.iconXs,
                  color: isSelected ? Colors.white : AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
