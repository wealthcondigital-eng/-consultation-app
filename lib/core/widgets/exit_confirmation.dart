import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_confirm_dialog.dart';

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
  const ExitConfirmation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        // Already popped — something else took the gesture, and asking now
        // would put a dialog over a screen that is on its way out.
        if (didPop) return;

        final leaving = await AppConfirmDialog.show(
          context,
          title: 'Close the app?',
          message: 'You can come back any time. Nothing is lost.',
          confirmLabel: 'Close',
          cancelLabel: 'Stay',
          icon: Icons.logout_rounded,
        );

        if (leaving) await SystemNavigator.pop();
      },
      child: child,
    );
  }
}
