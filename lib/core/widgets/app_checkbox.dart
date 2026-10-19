import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// A checkbox with a rich, multi-line label beside it.
///
/// The whole row is the tap target — a 16pt box on its own is well under the
/// minimum comfortable target size.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.semanticLabel,
    this.errorText,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Usually a `Text.rich` with tappable links inside.
  final Widget label;

  /// Plain-text equivalent of [label] for screen readers.
  final String semanticLabel;

  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: value,
          label: tr(semanticLabel),
          child: InkWell(
            onTap: enabled ? () => onChanged(!value) : null,
            borderRadius: BorderRadius.circular(sizing.radiusSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nudged down so it optically aligns with the first text line.
                Padding(
                  padding: EdgeInsets.only(top: sizing.spacingXxs * 0.5),
                  child: _Box(checked: value, hasError: hasError),
                ),
                SizedBox(width: sizing.spacingXs + 2),
                // Excluded because the InkWell already announces the label.
                Expanded(child: ExcludeSemantics(child: label)),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: sizing.spacingXxs),
          Text(tr(errorText!), style: sizing.text.error),
        ],
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.checked, required this.hasError});

  final bool checked;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: sizing.checkboxSize,
      height: sizing.checkboxSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusXs),
        border: Border.all(
          width: sizing.hairline,
          color: switch ((hasError, checked)) {
            (true, _) => AppColors.danger,
            (false, true) => AppColors.primary,
            (false, false) => AppColors.border,
          },
        ),
      ),
      child: checked
          ? Icon(
              Icons.check_rounded,
              size: sizing.checkboxSize * 0.75,
              color: Colors.white,
            )
          : null,
    );
  }
}
