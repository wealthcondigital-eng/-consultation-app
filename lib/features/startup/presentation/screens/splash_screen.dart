import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/branding/app_brand.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/logging/auth_logger.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/session/session_expiry.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/domain/usecases/sign_out.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../domain/entities/start_destination.dart';
import '../../domain/usecases/resolve_start_destination.dart';
import '../../../../core/l10n/tr.dart';

/// The screen every launch opens on: the brand on the gradient while the app
/// decides where the user belongs.
///
/// It decides first and looks like something second, but both matter. A
/// restored session is resolved in milliseconds, and a launch that flickers
/// through a blank frame into a dashboard reads as a glitch rather than as an
/// app starting — so the brand is held for [_minimumDwell] however fast the
/// answer arrives. The gradient and the lockup are the same ones the landing
/// screen opens with, which is what lets the splash hand over to it instead of
/// cutting to it.
///
/// This holds no state beyond "still deciding", so it calls the use case
/// directly rather than carrying a controller for one boolean.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// How long the brand stays up, even when the decision is instant.
  ///
  /// Long enough to read the wordmark, short enough that a returning user does
  /// not feel held: the intro settles at 700ms, and this leaves it a moment at
  /// rest before the screen changes.
  static const Duration _minimumDwell = Duration(milliseconds: 1200);

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _intro,
    curve: Curves.easeOut,
  );

  /// Rises to its full size rather than falling to it: the mark should read as
  /// arriving, and anything that starts oversized reads as a dismissal.
  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1,
  ).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic));

  Timer? _slowLaunch;

  /// The remainder of the dwell, and the future [_resolve] is waiting on for it.
  Timer? _dwell;
  Completer<void>? _dwellDone;

  /// Whether the decision has outlasted the dwell — a cold network, a server
  /// taking its time. Only then is there anything to report: a spinner shown
  /// for 200ms is noise, and one shown for four seconds is the difference
  /// between waiting and being stuck.
  bool _isSlow = false;

  @override
  void initState() {
    super.initState();
    _slowLaunch = Timer(_minimumDwell, () {
      if (mounted) setState(() => _isSlow = true);
    });
    _resolve();
  }

  @override
  void dispose() {
    _slowLaunch?.cancel();
    _releaseDwell();
    _intro.dispose();
    super.dispose();
  }

  /// Holds the brand on screen for the rest of [_minimumDwell], if any is left.
  ///
  /// A plain `Future.delayed` cannot be called off, and a splash that is torn
  /// down mid-hold would leave the timer running against a disposed tree.
  Future<void> _holdForBrand(Stopwatch since) {
    _slowLaunch?.cancel();

    final remaining = _minimumDwell - since.elapsed;
    if (remaining <= Duration.zero) return Future<void>.value();

    final held = _dwellDone = Completer<void>();
    _dwell = Timer(remaining, _releaseDwell);
    return held.future;
  }

  /// Lets [_resolve] go on — because the hold is over, or because the screen is
  /// going away and there is no brand left to hold. The `mounted` check on the
  /// far side of the await tells the two apart.
  void _releaseDwell() {
    _dwell?.cancel();
    _dwell = null;

    final held = _dwellDone;
    _dwellDone = null;
    if (held != null && !held.isCompleted) held.complete();
  }

  Future<void> _resolve() async {
    final elapsed = Stopwatch()..start();
    final entry = await sl<ResolveStartDestination>()();

    AuthLogger.event('STARTUP · resolved entry point', {
      'destination': entry.destination.name,
      'doctor application': entry.application?.status.name ?? '(none)',
    });

    await _holdForBrand(elapsed);

    // The awaits crossed async gaps; the widget may be gone — including
    // because the app-wide session gate saw the same 401 and has already moved
    // the app to the landing screen, which is a complete outcome, not a race to
    // recover from.
    if (!mounted) return;

    // The two outcomes that end the session and return to the role choice.
    //
    //  * registrationAbandoned — a registration form left half-done, with no
    //    usable profile on the other side to fall back to.
    //  * sessionExpired — the server refused the token outright. The account
    //    behind it is gone, and no local check could have caught that: the
    //    token is unexpired and well-formed, which is exactly why this used to
    //    end with a doctor staring at a certificate upload form.
    //
    // Ended here rather than carried into either app, so the next launch asks
    // the question again from a clean start.
    final endsSession =
        entry.destination == StartDestination.sessionExpired ||
        entry.destination == StartDestination.registrationAbandoned;

    if (endsSession) {
      await sl<SignOut>()().catchError((Object _) {});
      if (!mounted) return;

      // An unfinished registration is this screen's own finding, so it always
      // speaks. An expired session is a 401 the
      // app-wide gate can have seen first, so that message is claimed rather
      // than said twice.
      final shouldExplain =
          entry.destination != StartDestination.sessionExpired ||
          sl<SessionExpiry>().claim();

      if (shouldExplain) {
        final message = entry.notice ?? 'Please sign in again to continue.';

        // An unfinished registration is not a fault and nothing was lost that
        // the user had not already abandoned — so it is told as a fact, not
        // coloured as an error.
        if (entry.destination == StartDestination.registrationAbandoned) {
          AppSnackBar.info(context, message);
        } else {
          AppSnackBar.error(context, message);
        }
      }

      Navigator.of(context).pushReplacementNamed(AppRoutes.landing);
      return;
    }

    // A landing that carries a notice is [StartEntry.unconfirmed]: the lookups
    // could not answer and the session was deliberately kept, so this says what
    // happened without signing anybody out. Shown as a warning rather than an
    // error — nothing is broken on the user's side and the fix is to try again.
    if (entry.destination == StartDestination.landing && entry.notice != null) {
      AppSnackBar.warning(context, entry.notice!);
    }

    // Replaces rather than pushes: there is nothing to go back to, and a back
    // gesture must not return anyone to a blank splash.
    Navigator.of(context).pushReplacementNamed(
      switch (entry.destination) {
        StartDestination.landing ||
        // Unreachable — both handled above — but the switch must stay
        // exhaustive so adding a destination is a compile error rather than a
        // silent fall-through to the wrong app.
        StartDestination.sessionExpired ||
        StartDestination.registrationAbandoned => AppRoutes.landing,
        StartDestination.completeProfile => AppRoutes.completeProfile,
        StartDestination.home => AppRoutes.home,
        StartDestination.adminQueue => AppRoutes.adminQueue,
        StartDestination.doctorSetup => AppRoutes.doctorProfileSetup,
        StartDestination.doctorPending => AppRoutes.doctorApplicationPending,
        StartDestination.doctorApproved => AppRoutes.doctorApplicationApproved,
        StartDestination.doctorHome => AppRoutes.doctorHome,
      },
      // Only the pending screen reads it; the others ignore an extra argument.
      arguments: entry.application,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light icons at both ends: the gradient is the whole screen here, with
      // no white sheet at the bottom to hold the navigation bar.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.primaryEnd,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.brandSweep),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: sizing.screenPaddingH,
                vertical: sizing.screenPaddingV,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Balances the progress row below, so the lockup sits on the
                  // optical centre rather than being nudged up by it.
                  SizedBox(height: sizing.spacingXxxl),
                  Expanded(
                    child: Center(
                      child: FadeTransition(
                        opacity: _fade,
                        child: ScaleTransition(
                          scale: _scale,
                          child: const _SplashLockup(),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: sizing.spacingXxxl,
                    child: _isSlow ? const _SlowLaunchHint() : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge, wordmark and tagline, at the size a launch screen can afford.
class _SplashLockup extends StatelessWidget {
  const _SplashLockup();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final text = sizing.text;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The mark alone, without the tinted disc it used to sit in. A
        // speech bubble inside a circle is two containers arguing; the
        // silhouette is the logo, and on the gradient it needs no help.
        AppLogoMark(size: sizing.brandMarkSize, color: AppColors.onBrand),
        SizedBox(height: sizing.spacingXl),
        Text(
          AppBrand.name,
          style: text.brandTitle.copyWith(color: AppColors.onBrand),
        ),
        SizedBox(height: sizing.spacingXs),
        Text(
          tr(AppBrand.tagline),
          style: text.brandTagline.copyWith(color: AppColors.onBrandMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Shown only once a launch has outrun the dwell, so the screen says it is
/// still working rather than looking frozen.
class _SlowLaunchHint extends StatelessWidget {
  const _SlowLaunchHint();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Center(
      child: SizedBox.square(
        dimension: sizing.iconMd,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.onBrandMuted,
        ),
      ),
    );
  }
}
