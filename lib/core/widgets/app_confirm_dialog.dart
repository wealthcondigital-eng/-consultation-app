import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// How serious the thing being confirmed is, which decides the dialog's colour
/// and the weight of its confirm button.
enum AppConfirmTone {
  /// Ordinary. Brand teal.
  neutral,

  /// Irreversible, or nearly so — signing out, deleting a record. Red, and the
  /// confirm button is the filled one so it cannot be mistaken for Cancel.
  destructive,
}

/// A confirmation, built rather than assembled from `AlertDialog` defaults.
///
/// The app's dialogs used to be bare `AlertDialog`s with two text buttons, so
/// the most consequential action on a screen — logging out, losing an
/// unfinished registration — was two identical-looking words in the corner,
/// with nothing to say which one was the way out. Here the destructive choice
/// is a filled button under a tinted glyph, and Cancel is the quiet one, which
/// is the right way round for something a mis-tap cannot undo.
///
/// Returns true only when the confirm button was pressed. A barrier tap, a
/// back gesture and Cancel all answer false, so a caller never has to treat
/// null as "no" itself.
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.icon = Icons.help_outline_rounded,
    this.tone = AppConfirmTone.neutral,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final AppConfirmTone tone;

  /// Shows the dialog and answers whether it was confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    IconData icon = Icons.help_outline_rounded,
    AppConfirmTone tone = AppConfirmTone.neutral,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.45),
      builder: (context) => AppConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        tone: tone,
      ),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final isDestructive = tone == AppConfirmTone.destructive;

    final accent = isDestructive ? AppColors.danger : AppColors.primary;
    final tint = isDestructive
        ? AppColors.dangerSurface
        : AppColors.primarySurface;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: EdgeInsets.symmetric(
        horizontal: sizing.screenPaddingH,
        vertical: sizing.spacingXl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(sizing.r(24)),
      ),
      child: Padding(
        padding: EdgeInsets.all(sizing.cardPaddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The glyph carries the tone before the title is read, which is
            // the whole point of tinting it.
            Center(
              child: Container(
                width: sizing.r(64),
                height: sizing.r(64),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(icon, size: sizing.r(30), color: accent),
              ),
            ),
            SizedBox(height: sizing.spacingLg),
            Text(
              tr(title),
              textAlign: TextAlign.center,
              style: sizing.text.cardTitleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: sizing.spacingXs),
            Text(
              tr(message),
              textAlign: TextAlign.center,
              style: sizing.text.helperText.copyWith(height: 1.45),
            ),
            SizedBox(height: sizing.spacingXl),
            // Stacked, not side by side. At two buttons of equal width the
            // destructive one is a thumb's width from Cancel; stacking puts
            // the deliberate choice on top and the safe one where a reflex
            // lands.
            SizedBox(
              height: sizing.buttonHeight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(sizing.radiusMd),
                  ),
                ),
                child: Text(
                  tr(confirmLabel),
                  style: sizing.text.buttonLabel.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: sizing.spacingXs),
            SizedBox(
              height: sizing.buttonHeight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(sizing.radiusMd),
                  ),
                ),
                child: Text(
                  tr(cancelLabel),
                  style: sizing.text.buttonLabel.copyWith(
                    color: AppColors.textLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
