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
    this.activeColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Usually a `Text.rich` with tappable links inside.
  final Widget label;

  /// Plain-text equivalent of [label] for screen readers.
  final String semanticLabel;

  final String? errorText;
  final bool enabled;

  /// The fill and border when ticked. Defaults to [AppColors.primary]; a
  /// screen with its own accent — the anonymous consent popup is violet —
  /// passes that, so the tick matches the button beside it.
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: value,
          enabled: enabled,
          label: tr(semanticLabel),
          // A GestureDetector does not announce itself as tappable the way
          // an InkWell did, so the tap is offered to screen readers here.
          onTap: enabled ? () => onChanged(!value) : null,
          child: GestureDetector(
            // Opaque, so the gaps between the box and the words count as
            // part of the target rather than falling through.
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => onChanged(!value) : null,
            excludeFromSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nudged down so it optically aligns with the first text line.
                Padding(
                  padding: EdgeInsets.only(top: sizing.spacingXxs * 0.5),
                  child: _Box(
                    checked: value,
                    hasError: hasError,
                    activeColor: activeColor ?? AppColors.primary,
                  ),
                ),
                SizedBox(width: sizing.spacingXs + 2),
                // Excluded because the Semantics above already announces the
                // label.
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
  const _Box({
    required this.checked,
    required this.hasError,
    required this.activeColor,
  });

  final bool checked;
  final bool hasError;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: sizing.checkboxSize,
      height: sizing.checkboxSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? activeColor : AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusXs),
        border: Border.all(
          width: sizing.hairline,
          color: switch ((hasError, checked)) {
            (true, _) => AppColors.danger,
            (false, true) => activeColor,
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
