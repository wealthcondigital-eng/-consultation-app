import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../l10n/tr.dart';

/// A two-or-three-way switch: equal segments inside a tinted track, the
/// selected one lifted on a white card.
///
/// Use it where the options are few, mutually exclusive and worth showing at
/// once — a call type, say. Longer sets belong in a dropdown or a chip row.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.iconOf,
  });

  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;

  /// Optional glyph before each label.
  final IconData? Function(T option)? iconOf;

  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      height: sizing.fieldHeight,
      padding: EdgeInsets.all(sizing.spacingXxs),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusMd),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _Segment(
                label: labelOf(option),
                icon: iconOf?.call(option),
                isSelected: option == selected,
                onTap: () => onSelected(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusSm);
    final foreground = isSelected
        ? AppColors.primaryDeep
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        // Opaque so a tap on the padding inside a segment still selects it.
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: radius,
            boxShadow: isSelected ? AppShadows.segment : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon case final icon?) ...[
                Icon(icon, size: sizing.iconXs, color: foreground),
                SizedBox(width: sizing.spacingXxs + 2),
              ],
              Flexible(
                child: Text(
                  tr(label),
                  style: sizing.text.fieldLabel.copyWith(
                    color: foreground,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
