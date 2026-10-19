import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

enum AppButtonVariant {
  /// Filled brand blue — the one primary action on a screen.
  primary,

  /// Outlined brand blue — an equally weighted alternative.
  secondary,

  /// Neutral grey fill — third-party sign-in and other low-emphasis actions.
  tertiary,

  /// Deep blue fill — the single strongest action on a white card, where
  /// [primary] does not carry enough weight.
  emphasis,

  /// White fill with a neutral border — an alternative beside an [emphasis]
  /// action, without competing with it.
  outline,
}

enum AppButtonSize {
  /// Full-height, spanning its container — a screen's main action.
  regular,

  /// Shorter and tighter, for a button that sits inside a card row.
  compact,
}

/// The app's button. Height, radius and label size come from [AppSizing], so
/// it scales with the device instead of being pinned to the design frame.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.leading,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.leading,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.tertiary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.leading,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.tertiary;

  const AppButton.emphasis({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.leading,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.emphasis;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.leading,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.outline;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;

  bool get _isCompact => size == AppButtonSize.compact;

  /// Optional icon shown before the label, e.g. a provider logo.
  final Widget? leading;

  /// Swaps the label for a spinner and blocks input while work is in flight.
  final bool isLoading;

  Color get _foreground => switch (variant) {
    AppButtonVariant.primary => Colors.white,
    AppButtonVariant.emphasis => Colors.white,
    AppButtonVariant.secondary => AppColors.primary,
    AppButtonVariant.tertiary => AppColors.textLabel,
    AppButtonVariant.outline => AppColors.textPrimary,
  };

  Color get _background => switch (variant) {
    AppButtonVariant.primary => AppColors.primary,
    AppButtonVariant.emphasis => AppColors.primaryDeep,
    AppButtonVariant.secondary => AppColors.surface,
    AppButtonVariant.tertiary => AppColors.surfaceMuted,
    AppButtonVariant.outline => AppColors.surface,
  };

  /// Which variants draw a border, and in what colour.
  Color? get _borderColor => switch (variant) {
    AppButtonVariant.secondary => AppColors.primary,
    AppButtonVariant.outline => AppColors.border,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final child = isLoading
        ? SizedBox.square(
            dimension: sizing.iconSm,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_foreground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: sizing.spacingXs),
              ],
              Flexible(
                child: Text(
                  tr(label),
                  style: _isCompact
                      ? sizing.text.buttonLabelCompact
                      : sizing.text.buttonLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final style = ButtonStyle(
      // A compact button hugs its label instead of spanning its container.
      minimumSize: WidgetStatePropertyAll(
        _isCompact
            ? Size(0, sizing.buttonHeightCompact)
            : Size.fromHeight(sizing.buttonHeight),
      ),
      tapTargetSize: _isCompact ? MaterialTapTargetSize.shrinkWrap : null,
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: sizing.spacingMd),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            _isCompact ? sizing.radiusSm : sizing.radiusMd,
          ),
        ),
      ),
      foregroundColor: WidgetStatePropertyAll(_foreground),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        // Disabled fills dim; the muted variants already read as inactive.
        final isFilled =
            variant == AppButtonVariant.primary ||
            variant == AppButtonVariant.emphasis;
        if (states.contains(WidgetState.disabled) && isFilled && !isLoading) {
          return _background.withValues(alpha: 0.45);
        }
        return _background;
      }),
      side: WidgetStatePropertyAll(switch (_borderColor) {
        final Color color => BorderSide(
          // The neutral outline is a hairline; the brand outline is heavier.
          width: variant == AppButtonVariant.outline
              ? sizing.hairline
              : sizing.borderWidth,
          color: color,
        ),
        null => BorderSide.none,
      }),
      elevation: const WidgetStatePropertyAll(0),
    );

    // Loading buttons keep their filled look but reject taps.
    final effectiveOnPressed = isLoading ? null : onPressed;

    return switch (variant) {
      AppButtonVariant.secondary || AppButtonVariant.outline => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      _ => FilledButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
    };
  }
}
