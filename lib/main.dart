import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/router/app_routes.dart';
import 'core/config/app_config.dart';
import 'core/di/injector.dart';
import 'core/di/service_locator.dart';
import 'core/logging/auth_logger.dart';
import 'core/session/auth_session.dart';
import 'core/l10n/language_controller.dart';
import 'core/theme/theme_controller.dart';
import 'core/push/appointment_push.dart';
import 'core/push/call_kit_bridge.dart';
import 'core/push/push_lifecycle.dart';
import 'core/push/push_service.dart';
import 'features/payment/data/datasources/payment_gateway.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge to edge, with the system bars see-through and no contrast scrim.
  // Android 15+ ignores a navigation bar colour and, left to itself, greys the
  // three-button bar over — which hid the dark buttons our light screens ask
  // for. Each screen's `AnnotatedRegion` still picks the icon colour; this is
  // the default for any screen that does not.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
  );

  // Best-effort, and deliberately not fatal. Firebase is here for push
  // notifications; an app that refuses to start because a notification channel
  // could not be reached would trade a missed call alert for no app at all.
  // Anything that needs it checks `Firebase.apps` rather than assuming.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AuthLogger.event('FIREBASE · ready', {
      'project': DefaultFirebaseOptions.currentPlatform.projectId,
    });

    // The channel and the background handler, before any message can arrive.
    await PushService.configure();
  } catch (error) {
    AuthLogger.event('FIREBASE · unavailable', {'reason': error.toString()});
  }

  if (!AppConfig.hasApi) {
    throw StateError(
      'API_BASE_URL is empty. It defaults to the consultation API in server/ '
      'and can be overridden with --dart-define=API_BASE_URL=...',
    );
  }

  configureDependencies(backend: AppBackend.live);

  // Awaited before `runApp`: the splash gate reads `isSignedIn` synchronously
  // while deciding where to open, so the session has to be in memory by then.
  await sl<AuthSession>().restore();

  // Before the first frame, so a dark-mode user is not flashed white.
  await sl<ThemeController>().restore();
  await sl<LanguageController>().restore();

  // Re-file this handset against the restored session.
  //
  // Registering only at sign-in was a slow leak, and the database showed it:
  // one device token for the whole user base. Somebody signs in once, keeps the
  // session for weeks, and never registers again — so when FCM rotates their
  // token (it does, on reinstall, restore, and sometimes on its own) the server
  // is left holding a dead one and their phone goes quiet for good. Nobody
  // notices, because signing in is the one thing they never do again.
  //
  // Not awaited: it is a network call behind a permission prompt, and the app
  // must not hold on the splash screen waiting for it. Upserted on the token
  // server-side, so doing this on every launch costs one row, not one per run.
  if (sl<AuthSession>().isSignedIn) {
    unawaited(sl<PushService>().registerDevice());
  }

  // And again on every resume, for the launch that had no network yet and for
  // the permission somebody turned on in Settings afterwards. Does nothing once
  // the token is filed.
  PushLifecycleObserver().start();

  AuthLogger.event('APP · backend ready', {
    'api': AppConfig.apiBaseUrl,
    'restored session': sl<AuthSession>().userId ?? 'none',
    // Named out loud, because the one thing that cannot be diagnosed from the
    // outside is which gateway is about to run. A build that silently resolved
    // the stand-in booked consultations nobody paid for and looked, from the
    // screen, exactly like Razorpay failing to open.
    'payments': sl<PaymentGateway>().runtimeType.toString(),
    'razorpay key': AppConfig.razorpayKeyId.isEmpty
        ? 'NONE — checkout cannot open'
        : AppConfig.razorpayKeyId,
  });

  // Where a tapped reminder goes. Wired here rather than inside `PushService`,
  // which is core and has no business knowing the route table — and wired after
  // `configureDependencies`, so the navigator it reaches for exists.
  //
  // Set after `PushService.configure` on purpose: the tap that *launched* the
  // app is already waiting by then, and the setter replays it rather than
  // dropping it on the floor.
  PushService.onAppointmentOpened = _openAppointment;

  // Answers from the phone's own ringing screen — the one a doctor sees with
  // the app in the background or killed. Started after the session is
  // restored, because a Decline is sent as the signed-in doctor.
  sl<CallKitBridge>().start();

  // Opens on the gate rather than the landing screen so a restored session
  // skips login. The default stays `landing` for the widget tests.
  runApp(const TeleconsultApp(initialRoute: AppRoutes.splash));
}

/// Takes someone to whatever their notification was about.
///
/// The notifications page rather than the consultation itself, deliberately.
/// The reminder may be for an appointment that cannot be opened yet — the join
/// window is fifteen minutes wide, and three of the four reminders land outside
/// it — so routing straight to the call screen would land half of them on "this
/// appointment has not started yet". The list shows the countdown and the join
/// button appears on it when the window opens.
void _openAppointment(AppointmentPush appointment) {
  final navigator = TeleconsultApp.navigatorKey.currentState;

  // No navigator means the app is still starting. Nothing to do and nothing to
  // keep: the bell picks the same notification up on its first load.
  if (navigator == null) return;

  AuthLogger.event('PUSH · appointment tapped', {
    'consultation': appointment.consultationId,
    'kind': appointment.kind.name,
  });

  navigator.pushNamed(AppRoutes.notifications);
}
