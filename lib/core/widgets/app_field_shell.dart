import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// The label / box / error-message frame shared by every form field.
///
/// Field widgets supply only their interactive middle; this owns the chrome so
/// a text input and a dropdown are pixel-identical.
class AppFieldShell extends StatelessWidget {
  const AppFieldShell({
    super.key,
    required this.label,
    required this.child,
    this.errorText,
    this.height,
    this.leading,
    this.trailing,
    this.helperText,
    this.borderColor,
    this.alignment = Alignment.center,
  });

  final String label;
  final Widget child;
  final String? errorText;

  /// Defaults to the standard field height.
  final double? height;

  /// Optional glyph before the input, e.g. the person icon on a name field.
  final Widget? leading;

  /// Optional glyph after the input, e.g. a tick on a value the backend has
  /// already checked.
  final Widget? trailing;

  /// A note under the box explaining what the value is used for. Hidden while
  /// [errorText] is showing — the error is the more urgent message.
  final String? helperText;

  /// Overrides the resting border colour, for a field the design emphasises.
  /// An error still wins over it.
  final Color? borderColor;

  /// Where the [child] sits in the box. Top-aligned for a multi-line field.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(label), style: sizing.text.fieldLabel),
        SizedBox(height: sizing.spacingXs),
        Container(
          height: height ?? sizing.fieldHeight,
          padding: EdgeInsets.symmetric(horizontal: sizing.spacingMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(sizing.radiusInput),
            border: Border.all(
              width: sizing.hairline,
              color: hasError
                  ? AppColors.danger
                  : borderColor ?? AppColors.border,
            ),
          ),
          child: Align(
            alignment: alignment,
            child: Row(
              children: [
                if (leading case final leading?) ...[
                  leading,
                  SizedBox(width: sizing.spacingXs),
                ],
                Expanded(child: child),
                if (trailing case final trailing?) ...[
                  SizedBox(width: sizing.spacingXs),
                  trailing,
                ],
              ],
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: sizing.spacingXxs),
          Text(tr(errorText!), style: sizing.text.error),
        ] else if (helperText case final helperText?) ...[
          SizedBox(height: sizing.spacingXxs),
          Text(tr(helperText), style: sizing.text.complianceNote),
        ],
      ],
    );
  }
}
