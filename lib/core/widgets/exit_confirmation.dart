import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../branding/app_brand.dart';
import '../l10n/tr.dart';
import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import 'app_logo.dart';

/// Asks before the back gesture closes the app.
///
/// Wraps the screens with nothing behind them — the home dashboards and the
/// landing screen. On those, Android's back gesture pops the last route off an
/// empty stack, which closes the app: a patient halfway through reading their
/// appointments swipes once too often and the app is gone, with no way to tell
/// a deliberate exit from a mis-swipe.
///
/// `canPop: false` is what routes the gesture here rather than to the system.
/// It costs the predictive-back preview animation on these screens, which is a
/// fair trade for not closing by accident — and everywhere else in the app the
/// gesture still pops a route, where it does exactly what it looks like.
///
/// Exits through [SystemNavigator.pop] rather than `exit(0)`: it is the
/// platform's own "user asked to leave" path, so the app is backgrounded the
/// way the home button would do it instead of being killed mid-write.
class ExitConfirmation extends StatelessWidget {
  const ExitConfirmation({super.key, required this.child, this.onBack});

  final Widget child;

  /// Gets the first back press, and answers true when it dealt with it.
  ///
  /// The home screens use it to go back to the dashboard from another tab:
  /// back on Appointments or Profile means "back to home", not "close the
  /// app", so the dialog only appears once the person is on the dashboard.
  final bool Function()? onBack;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        // Already popped — something else took the gesture, and asking now
        // would put a dialog over a screen that is on its way out.
        if (didPop) return;
        if (onBack?.call() ?? false) return;

        final leaving = await ExitAppDialog.show(context);
        if (leaving) await SystemNavigator.pop();
      },
      child: child,
    );
  }
}

/// The "leave the app?" dialog: the brand mark, one line on what leaving
/// means, and Stay as the filled button — a mis-swipe is the commoner reason
/// to be here, so the reflex tap keeps them in.
class ExitAppDialog extends StatelessWidget {
  const ExitAppDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final leaving = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.45),
      builder: (_) => const ExitAppDialog(),
    );

    return leaving ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusMd);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: EdgeInsets.symmetric(
        horizontal: sizing.screenPaddingH * 1.5,
        vertical: sizing.spacingXl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(sizing.r(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A brand band rather than a warning glyph: leaving is not an
          // error, and the mark says whose app is asking.
          Container(
            padding: EdgeInsets.symmetric(vertical: sizing.spacingLg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.brandGradient,
              ),
            ),
            child: Center(
              child: Container(
                width: sizing.r(64),
                height: sizing.r(64),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.onBrandSurface,
                  shape: BoxShape.circle,
                ),
                child: AppLogoMark(
                  size: sizing.r(34),
                  color: AppColors.onBrand,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              sizing.cardPaddingLarge,
              sizing.spacingLg,
              sizing.cardPaddingLarge,
              sizing.cardPaddingLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('Leave {app}?', {'app': AppBrand.name}),
                  textAlign: TextAlign.center,
                  style: sizing.text.cardTitleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: sizing.spacingXs),
                Text(
                  tr(
                    'You will stay signed in, and your appointment '
                    'reminders will still reach you.',
                  ),
                  textAlign: TextAlign.center,
                  style: sizing.text.helperText.copyWith(height: 1.45),
                ),
                SizedBox(height: sizing.spacingXl),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: sizing.buttonHeight,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textLabel,
                            side: BorderSide(
                              color: AppColors.border,
                              width: sizing.borderWidth,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: radius),
                          ),
                          child: Text(
                            tr('Exit'),
                            style: sizing.text.buttonLabel.copyWith(
                              color: AppColors.textLabel,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: sizing.spacingSm),
                    Expanded(
                      child: SizedBox(
                        height: sizing.buttonHeight,
                        child: FilledButton(
                          autofocus: true,
                          onPressed: () => Navigator.of(context).pop(false),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: radius),
                          ),
                          child: Text(
                            tr('Stay'),
                            style: sizing.text.buttonLabel.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
