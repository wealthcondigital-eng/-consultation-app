import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// A horizontal row of single-select pill chips.
///
/// Scrolls rather than wrapping, so a long set of options never pushes the
/// content below it around on a narrow screen.
class AppChoiceChips<T> extends StatelessWidget {
  const AppChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return SizedBox(
      height: sizing.chipHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => SizedBox(width: sizing.spacingXs),
        itemBuilder: (context, index) {
          final option = options[index];

          return _Chip(
            label: labelOf(option),
            isSelected: option == selected,
            onTap: () => onSelected(option),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
    final radius = BorderRadius.circular(sizing.radiusPill);

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? AppColors.primary : AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: sizing.spacingMd - 2),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: isSelected
                  ? null
                  : Border.all(width: sizing.hairline, color: AppColors.border),
            ),
            child: Text(
              tr(label),
              style: sizing.text.chipLabel.copyWith(
                color: isSelected ? Colors.white : AppColors.textLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
