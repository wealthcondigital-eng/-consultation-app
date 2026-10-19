import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/branding/app_brand.dart';
import '../core/di/service_locator.dart';
import '../core/logging/auth_logger.dart';
import '../core/network/connectivity_monitor.dart';
import '../core/responsive/app_sizing.dart';
import '../core/session/session_expiry.dart';
import '../core/theme/app_theme.dart';
import '../core/l10n/language_controller.dart';
import '../core/theme/theme_controller.dart';
import '../core/widgets/app_snackbar.dart';
import '../core/widgets/offline_gate.dart';
import '../features/auth/domain/usecases/sign_out.dart';
import '../features/call/presentation/controllers/active_call.dart';
import '../features/call/presentation/screens/call_screen.dart';
import '../features/call/presentation/widgets/ongoing_call_bar.dart';
import '../features/consultation/presentation/screens/consultation_feedback_screen.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';

class TeleconsultApp extends StatefulWidget {
  const TeleconsultApp({
    super.key,
    this.initialRoute = AppRoutes.landing,
    this.initialRouteArguments,
  });

  /// Where the app opens. Overridden to resume an interrupted flow, to honour
  /// a deep link, or to drive a single screen under test.
  final String initialRoute;

  /// Arguments for [initialRoute], for the screens that take them.
  final Object? initialRouteArguments;

  /// Lets the session gate below reach the navigator from outside any route.
  ///
  /// A 401 can arrive while any screen is open, and the screen that made the
  /// call is not always the one that should react — so the redirect is driven
  /// from above the navigator rather than from whichever widget happened to be
  /// holding the request.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<TeleconsultApp> createState() => _TeleconsultAppState();
}

class _TeleconsultAppState extends State<TeleconsultApp> {
  late final ThemeController _theme = sl<ThemeController>();
  late final LanguageController _language = sl<LanguageController>();
  late final ActiveCall _activeCall = sl<ActiveCall>();

  @override
  void initState() {
    super.initState();
    _theme.addListener(_onThemeChanged);
    _language.addListener(_onThemeChanged);
    _activeCall.onEndedAway = _onCallEndedAway;
  }

  /// Back to the call in progress, from the ongoing-call bar.
  void _returnToCall() {
    final args = _activeCall.args;
    if (args == null) return;
    TeleconsultApp.navigatorKey.currentState?.pushNamed(
      AppRoutes.call,
      arguments: args,
    );
  }

  /// A call that ended while its screen was not open — the other side hung
  /// up while this person was elsewhere in the app. A patient is asked for
  /// feedback, exactly as the call screen would have; a doctor is left where
  /// they are, the bar simply gone.
  void _onCallEndedAway(CallArgs args, int durationInSeconds) {
    final consultationId = args.consultationId;
    if (!args.isCaller || consultationId == null) return;

    TeleconsultApp.navigatorKey.currentState?.pushNamed(
      AppRoutes.consultationFeedback,
      arguments: ConsultationFeedbackArgs(
        consultationId: consultationId,
        doctor: args.doctor,
        mode: args.mode,
        durationInSeconds: durationInSeconds,
      ),
    );
  }

  @override
  void dispose() {
    _theme.removeListener(_onThemeChanged);
    _language.removeListener(_onThemeChanged);
    super.dispose();
  }

  /// Repaints every screen in the new palette or language.
  ///
  /// The colour tokens are read in `build`, so a rebuild is all a switch
  /// needs — but a `const` widget is skipped by an ordinary rebuild, so every
  /// element is marked dirty rather than only this one. The navigation stack
  /// and every screen's state are kept.
  void _onThemeChanged() {
    setState(() {});
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    final initialRoute = widget.initialRoute;
    final initialRouteArguments = widget.initialRouteArguments;
    final navigatorKey = TeleconsultApp.navigatorKey;

    return MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      // Built from the active palette, so it is always the theme on screen;
      // `ThemeController` decides which that is.
      theme: AppTheme.current,
      themeMode: ThemeMode.light,
      // The app's own text goes through `tr()`; these cover what Flutter
      // itself draws — a date picker, a text field's Paste.
      locale: _language.language.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      // MaterialApp.initialRoute alone cannot carry arguments, so the first
      // route is generated here instead.
      onGenerateInitialRoutes: (name) => [
        AppRouter.onGenerateRoute(
          RouteSettings(name: name, arguments: initialRouteArguments),
        ),
      ],
      builder: (context, child) {
        // Resolve the responsive dimensions once, above the navigator, so every
        // route reads the same tokens via `context.sizing`.
        // The offline screen is laid over the session gate rather than under
        // it: a dropped connection hides the app, and being signed out
        // underneath is not something to show a user who cannot act on it yet.
        return AppSizingScope(
          child: OfflineGate(
            monitor: sl<ConnectivityMonitor>(),
            // The ongoing-call bar sits over every route, so a call left by
            // back stays one tap away wherever the person goes.
            child: OngoingCallBar(
              activeCall: _activeCall,
              onReturn: _returnToCall,
              child: _SessionExpiryGate(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Sends the user back to the role choice the moment the server stops
/// recognising their session.
///
/// Installed once, above every route, because a 401 can answer any request on
/// any screen and the correct response never depends on which. Before this, a
/// rejected session surfaced as an ordinary error on whatever screen asked —
/// a dashboard tile that would not load, a form that would not save — with the
/// user still apparently signed in and no way back to the landing screen short
/// of clearing the app's data.
///
/// The startup path in `SplashScreen` covers the same event when it happens
/// during a launch. Both can see one 401, so the message is claimed rather than
/// shown twice; see [SessionExpiry.claim].
class _SessionExpiryGate extends StatefulWidget {
  const _SessionExpiryGate({required this.child});

  final Widget child;

  @override
  State<_SessionExpiryGate> createState() => _SessionExpiryGateState();
}

class _SessionExpiryGateState extends State<_SessionExpiryGate> {
  /// Looked up rather than injected: this sits inside `MaterialApp.builder`,
  /// above any provider a screen could offer.
  late final SessionExpiry _expiry = sl<SessionExpiry>();

  @override
  void initState() {
    super.initState();
    _expiry.addListener(_onExpired);
  }

  @override
  void dispose() {
    _expiry.removeListener(_onExpired);
    super.dispose();
  }

  /// True while the redirect below is in flight.
  ///
  /// Signing out is itself an API call, and it is made with the very token the
  /// server just refused — so it answers 401 as well, from inside this handler.
  /// Belt and braces alongside the latch in [SessionExpiry]: between them, one
  /// dead session can only ever produce one sign-out and one redirect.
  bool _isRedirecting = false;

  Future<void> _onExpired() async {
    if (_isRedirecting) return;

    // The splash may get there first during a launch, in which case it owns the
    // message and this only has to stay out of the way.
    if (!_expiry.claim()) return;

    AuthLogger.event('SESSION · 401 gate fired', {
      'action': 'sign out, then landing screen',
    });

    _isRedirecting = true;
    try {
      // Clears the stored token. Best-effort by design: the sign-out call
      // itself will be refused with the same 401, and `signOut` clears locally
      // anyway.
      await sl<SignOut>()().catchError((Object _) {});

      final navigator = TeleconsultApp.navigatorKey.currentState;
      if (navigator == null || !mounted) return;

      AppSnackBar.error(
        navigator.context,
        'Your session has ended. Please sign in again.',
      );

      // Everything behind this belonged to the account that no longer exists,
      // so the whole stack goes rather than being left for a back gesture to
      // reach.
      await navigator.pushNamedAndRemoveUntil(
        AppRoutes.landing,
        (route) => false,
      );
    } finally {
      _isRedirecting = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
