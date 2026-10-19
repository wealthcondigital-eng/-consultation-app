import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notifications/domain/entities/app_notification.dart';
import '../logging/auth_logger.dart';
import '../network/api_client.dart';
import '../session/session_store.dart';
import 'appointment_push.dart';
import 'call_kit_bridge.dart';
import 'incoming_call_push.dart';

/// Handles a message that arrived while the app was killed or backgrounded.
///
/// Must be a **top-level function**: Android starts a separate Dart isolate for
/// it with none of the app's state, so a closure or a method would have nothing
/// to close over. Nothing here may touch the widget tree — there is no tree.
@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  // Appointment messages are drawn by the system, not by us. They carry an FCM
  // `notification` block precisely so a killed app still shows them, and
  // Android hands the same message to this handler as well — so showing one
  // here would put the reminder in the tray twice.
  if (message.notification != null) return;
  if (message.data['type'] == 'appointment') return;

  // The patient hung up, the ring timed out, or the doctor declined on another
  // device. Takes the ringing screen down; nothing else would, with the app
  // not running.
  if (callEndedIn(message.data) case final consultationId?) {
    await PushService.dismissCall(consultationId);
    return;
  }

  final call = IncomingCallPush.tryParse(message.data);
  if (call == null) return;

  // Nobody signed in on this phone. The server forgets a device on sign-out,
  // but a sign-out that could not reach it leaves the token behind — and a
  // ringing call nobody here can answer, whose Accept opens a login screen, is
  // worse than silence. The ring times out and goes to another doctor.
  if (!await hasStoredSession()) return;

  // A fresh isolate, so Firebase and the notification plugin are both
  // uninitialised here even though `main` set them up minutes ago.
  await Firebase.initializeApp();

  // Android gets the phone's own incoming-call screen: full screen over the
  // lock screen, ringing until answered, with Accept and Decline on it. iOS
  // cannot be woken to draw one by an ordinary push — that needs PushKit — so
  // it keeps the notification until then.
  if (defaultTargetPlatform == TargetPlatform.android) {
    // In this process, before the call is up: a Decline tapped while the app
    // is killed is delivered to Dart only if a handler was registered here.
    await CallKitBridge.registerBackgroundHandler();
    await CallKitBridge.show(call);
    return;
  }

  await PushService.showIncomingCall(call);
}

/// True when this phone holds a signed-in session. Read straight from storage,
/// because the background isolate has no `AuthSession` in memory.
Future<bool> hasStoredSession({
  SessionStore store = const PreferencesSessionStore(),
}) async {
  try {
    final token = (await store.read())?['token'];
    return token is String && token.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// The consultation a `call_ended` message is about, or null when the message
/// is something else.
String? callEndedIn(Map<String, dynamic> data) {
  if (data['type'] != 'call_ended') return null;

  final id = data['consultationId'];
  return id is String && id.isNotEmpty ? id : null;
}

/// Everything push: the device token the server rings, and the notification a
/// call arrives as.
///
/// Push is an **addition** to the in-app polling, not a replacement. A doctor
/// with the app open has always seen incoming consultations through
/// `/consultations/incoming`; this is what reaches one whose phone is face-down
/// on a table with the app killed, which polling by definition cannot do.
class PushService {
  PushService(this._client);

  final ApiClient _client;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// What Android tints the small icon and the app name with.
  ///
  /// Matches `notification_accent` in colors.xml, which is what Firebase uses
  /// for the same notification when the system draws it instead of us — the
  /// two have to agree or one reminder looks like a different app's.
  static const Color _brand = Color(0xFF1B7B80);

  /// Its own channel, at the highest importance Android offers.
  ///
  /// A call is not a message. On the default channel it would arrive as a line
  /// in the tray with the notification sound, which is indistinguishable from a
  /// promotion — and the patient is waiting thirty seconds for an answer.
  static const AndroidNotificationChannel _callChannel =
      AndroidNotificationChannel(
        'incoming_calls',
        'Incoming consultations',
        description: 'Rings when a patient is calling.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  /// Where booking confirmations and reminders land.
  ///
  /// Separate from the call channel, and the separation is the point. Android
  /// lets people turn a channel off by itself, and a reminder that rang like an
  /// incoming call is one they would silence — taking the calls with it,
  /// because on one channel there is no way to keep the second without the
  /// first. `high` rather than `max`: it should make a sound and appear over
  /// what they are doing, not seize the lock screen.
  static const AndroidNotificationChannel _appointmentChannel =
      AndroidNotificationChannel(
        // Must match `channelId: 'appointments'` on the server's
        // `PushService.sendAppointment`, or the system draws the notification
        // on a fallback channel the user has never seen and cannot tune.
        'appointments',
        'Appointment reminders',
        description:
            'Confirms a booking, and reminds you before a consultation starts.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

  /// Appointment messages as they arrive, for whatever is on screen.
  ///
  /// The notification bell listens: a reminder that lands while the app is open
  /// has to turn the dot on without waiting for the next lifecycle resume,
  /// which would otherwise never come while the user is already looking at it.
  static final StreamController<AppointmentPush> _appointments =
      StreamController<AppointmentPush>.broadcast();

  static Stream<AppointmentPush> get appointments => _appointments.stream;

  /// A tap that arrived before anything was listening for one.
  ///
  /// The case is the ordinary one: `configure` runs at the top of `main`, and
  /// the tap that launched the app is waiting there already — but the router
  /// does not exist yet, so there is nothing to route to for another few
  /// hundred milliseconds. Held here and replayed the moment [onAppointmentOpened]
  /// is set, rather than dropped, which would make a tapped reminder open the
  /// app on the dashboard as if nothing had been tapped.
  static AppointmentPush? _pendingOpen;

  static void Function(AppointmentPush)? _onAppointmentOpened;

  /// Called when the user taps an appointment notification.
  ///
  /// A hook rather than a direct `Navigator` call: this is core, the routes are
  /// not, and a push service that imports the router is one no test can run
  /// without one. `main` wires it.
  static set onAppointmentOpened(void Function(AppointmentPush)? handler) {
    _onAppointmentOpened = handler;

    final pending = _pendingOpen;
    if (handler == null || pending == null) return;

    _pendingOpen = null;
    handler(pending);
  }

  /// Routes a tap, or keeps it until something can.
  static void _openAppointment(AppointmentPush appointment) {
    final handler = _onAppointmentOpened;
    if (handler == null) {
      _pendingOpen = appointment;
      return;
    }
    handler(appointment);
  }

  String? _token;

  /// The token this device is currently registered under, if any.
  String? get token => _token;

  /// Prepares the channel and the background handler. Called once from `main`.
  ///
  /// Never throws. A phone that refuses notification permission, or a build
  /// with no Firebase, must still run the app — it simply will not ring when
  /// closed.
  static Future<void> configure() async {
    try {
      FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);

      // The same call, arriving while the app is open. The doctor may be on
      // another screen entirely — reading a report, or in the middle of a
      // form — and the in-app ring only exists on the screens that poll, so
      // the notification is what reaches them everywhere else.
      FirebaseMessaging.onMessage.listen((message) async {
        if (callEndedIn(message.data) case final consultationId?) {
          await dismissCall(consultationId);
          return;
        }

        final call = IncomingCallPush.tryParse(message.data);
        if (call != null) {
          // The same ringing call as a closed app, on Android. A notification
          // on the call channel plays its tone once and stops, which with the
          // app open was the only sound the call made. With the phone in use,
          // Android shows the ringing call as a heads-up over whatever is on
          // screen rather than taking the screen over, so it interrupts
          // nothing — and a locked phone gets the full-screen ring.
          if (defaultTargetPlatform == TargetPlatform.android) {
            await CallKitBridge.show(call);
            return;
          }

          // Foreground, so no full-screen intent — see [showIncomingCall].
          await showIncomingCall(call, overTheLockScreen: false);
          return;
        }

        // Foreground is the one case the system draws nothing at all: Android
        // and iOS both suppress a `notification` block while the app is in
        // front, on the assumption the app will say something itself. This is
        // the app saying it. Without this line, a reminder that arrives while
        // someone is using the app is silently swallowed — which is the worst
        // of the three states to lose it in, because they are right there.
        final appointment = AppointmentPush.tryParse(message.data);
        if (appointment != null) await showAppointment(appointment);
      });

      // Tapped while the app was in the background. The system drew this one,
      // so the local-notification tap handler never sees it.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final appointment = AppointmentPush.tryParse(message.data);
        if (appointment != null) _openAppointment(appointment);
      });

      // Tapped while the app was dead, which is how a reminder for a 9 AM
      // appointment is usually opened. The message is waiting rather than
      // delivered, so nothing above fires for it and it has to be asked for.
      final launch = await FirebaseMessaging.instance.getInitialMessage();
      if (launch != null) {
        final appointment = AppointmentPush.tryParse(launch.data);
        if (appointment != null) _openAppointment(appointment);
      }

      await _notifications.initialize(
        // Tapping the notification only brings the app forward. Answering is
        // deliberately left to the doctor's own incoming-consultation ring,
        // which has accept and decline on it — a notification that answered
        // would put a patient through to a doctor who only meant to look at
        // who was ringing.
        onDidReceiveNotificationResponse: (response) async {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;

            // An appointment drawn by us, which only happens in the
            // foreground. Routed rather than dismissed: there is no call to
            // stop ringing, and the tap is someone asking to be taken to it.
            final appointment = AppointmentPush.tryParse(data);
            if (appointment != null) {
              _openAppointment(appointment);
              return;
            }

            await dismissCall(data['consultationId'] as String? ?? '');
          } catch (_) {
            // A payload that will not parse is still a notification that has
            // done its job by waking the phone.
          }
        },
        settings: const InitializationSettings(
          // The monochrome mark, not the launcher icon. Android keeps only
          // the alpha channel of a small icon and paints the rest white, and
          // every pixel of the launcher icon is opaque — so '@mipmap/ic_launcher'
          // here is a solid white square where the logo should be. See
          // res/drawable/ic_stat_notification.xml.
          android: AndroidInitializationSettings('ic_stat_notification'),
          iOS: DarwinInitializationSettings(
            // The call notification asks for these itself when it arrives; a
            // permission prompt on first launch, before the user has any idea
            // what the app does, is one most people refuse.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_callChannel);

      // Created even though the server names it on every message: Android only
      // honours a `channelId` for a channel that already exists, and a message
      // naming one that does not is drawn on a default channel with no sound
      // settings the user ever chose. Creating both up front also means both
      // appear in the system settings before the first notification, which is
      // where somebody looks when they want reminders but not calls.
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_appointmentChannel);
    } catch (error) {
      AuthLogger.event('PUSH · could not configure', {'reason': '$error'});
    }
  }

  /// Puts a ringing call on screen.
  ///
  /// `fullScreenIntent` is what turns a tray line into a call: on a locked
  /// phone Android shows the notification over the lock screen rather than
  /// behind it. Static because the background isolate has no instance to
  /// call — see [handleBackgroundMessage].
  ///
  /// [overTheLockScreen] is false when the app is already in front, and that
  /// distinction is not cosmetic. A full-screen intent does not draw over the
  /// app — it **launches an activity** over whatever is on screen, and the app
  /// is not always the thing on screen. During a Razorpay checkout the thing
  /// on screen belongs to the payment SDK, and slamming an activity over it
  /// closes the sheet: the patient taps Pay, a call notification arrives, and
  /// checkout vanishes with no explanation and no payment.
  ///
  /// Foregrounded there is nothing a full-screen intent buys anyway. The
  /// person is holding the phone and looking at it; a heads-up notification at
  /// max importance is already unmissable, and the in-app ring is what answers.
  static Future<void> showIncomingCall(
    IncomingCallPush call, {
    bool overTheLockScreen = true,
  }) async {
    try {
      await _notifications.show(
        id: call.consultationId.hashCode,
        title: call.callerName,
        body:
            // The concern is the doctor's reason to answer, so it is the body
            // rather than the mode — which the icon and the title already imply.
            call.concern ?? '${call.modeLabel} · tap to answer',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _callChannel.id,
            _callChannel.name,
            channelDescription: _callChannel.description,
            icon: 'ic_stat_notification',
            color: _brand,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            // Keeps ringing rather than showing once and falling silent.
            ongoing: true,
            autoCancel: false,
            fullScreenIntent: overTheLockScreen,
            // A call pattern rather than a single buzz: two long pulses, the
            // way a phone ringing sounds to a hand in a pocket.
            vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
            ticker: 'Incoming consultation',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: jsonEncode({
          'consultationId': call.consultationId,
          'channelId': call.channelId,
          'mode': call.mode.name,
        }),
      );
    } catch (error) {
      AuthLogger.event('PUSH · could not show the call', {'reason': '$error'});
    }
  }

  /// Puts a booking confirmation or a reminder in the tray.
  ///
  /// Only ever called for a message that arrived **while the app was in the
  /// foreground**, which is the one state where the system draws nothing of its
  /// own. Backgrounded or killed, the FCM `notification` block is what appears,
  /// and drawing a second one here would double every reminder.
  ///
  /// Also announces it on [appointments], so the unread dot turns on without
  /// anybody having to leave the app and come back.
  static Future<void> showAppointment(AppointmentPush appointment) async {
    if (!_appointments.isClosed) _appointments.add(appointment);

    try {
      await _notifications.show(
        // Keyed by consultation, so the four reminders for one appointment
        // replace each other in the tray rather than stacking into a column of
        // four saying progressively more urgent versions of the same thing.
        id: appointment.consultationId.hashCode,
        title: appointment.title,
        body: appointment.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _appointmentChannel.id,
            _appointmentChannel.name,
            channelDescription: _appointmentChannel.description,
            icon: 'ic_stat_notification',
            color: _brand,
            importance: Importance.high,
            priority: Priority.high,
            // A reminder, not a call: swipeable, dismissed when tapped, and it
            // does not sit in the tray after the consultation has started.
            ongoing: false,
            autoCancel: true,
            category: AndroidNotificationCategory.reminder,
            // The body is a sentence, and a sentence in a one-line tray entry
            // is a sentence nobody finishes reading.
            styleInformation: BigTextStyleInformation(appointment.body),
            ticker: appointment.title,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            // The two-minute one is the reason this exists: time-sensitive is
            // what gets through a Focus mode, and somebody about to take a
            // consultation is very likely in one. The earlier ones are not
            // urgent enough to earn it.
            interruptionLevel: appointment.isStarting
                ? InterruptionLevel.timeSensitive
                : InterruptionLevel.active,
          ),
        ),
        payload: jsonEncode({
          'type': 'appointment',
          'kind': _kindKey(appointment.kind),
          'consultationId': appointment.consultationId,
          'title': appointment.title,
          'body': appointment.body,
          'startsAt': appointment.startsAt?.toIso8601String() ?? '',
          'notificationId': appointment.notificationId ?? '',
        }),
      );
    } catch (error) {
      AuthLogger.event('PUSH · could not show the appointment', {
        'reason': '$error',
      });
    }
  }

  /// The wire spelling of a kind, so a tap can be parsed back by the same code
  /// that reads one off FCM.
  static String _kindKey(NotificationKind kind) => switch (kind) {
    NotificationKind.bookingConfirmed => 'booking_confirmed',
    NotificationKind.consultationReminder => 'consultation_reminder',
    NotificationKind.consultationStarting => 'consultation_starting',
    NotificationKind.general => 'general',
  };

  /// Stops a call ringing — answered, declined, or the caller gave up.
  ///
  /// Both ways it can be ringing: the notification drawn while the app was
  /// open, and the full-screen call drawn while it was not.
  static Future<void> dismissCall(String consultationId) async {
    try {
      await _notifications.cancel(id: consultationId.hashCode);
    } catch (_) {
      // A notification that would not go away is not worth an error screen.
    }

    await CallKitBridge.end(consultationId);
  }

  /// Reads this device's token and tells the server about it.
  ///
  /// Called after sign-in and on every launch with a restored session: the
  /// token is filed **against a user**, so registering before there is one
  /// would file it against nobody and the first call would ring no phone.
  ///
  /// **Permission is asked for but not required.** This is the bug that left a
  /// doctor unreachable for weeks, and it is worth being explicit about,
  /// because the old shape looked completely reasonable: ask permission, and if
  /// it is refused, give up. But on Android the notification permission governs
  /// whether a notification may be *displayed* — it has nothing to do with
  /// whether FCM will issue a token. Returning early on a refusal threw away a
  /// perfectly good address, permanently: nothing re-ran, so the one moment
  /// somebody tapped "Don't allow" decided that their phone could never be
  /// reached again, even after they turned notifications back on in Settings.
  ///
  /// Registering anyway costs nothing and fixes itself. A device whose owner
  /// later grants the permission starts receiving immediately, with no
  /// re-registration and nothing to notice it happened.
  Future<void> registerDevice() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Attached before anything that can fail or return early, and only once.
      // FCM rotates tokens — on reinstall, on restore, and occasionally on its
      // own — and a device that does not re-register after a rotation is a
      // phone the server believes it can reach and cannot.
      if (!_listeningForRotation) {
        _listeningForRotation = true;
        messaging.onTokenRefresh.listen(_sendWithRetry);
      }

      final settings = await messaging.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!granted) {
        AuthLogger.event('PUSH · permission not granted', {
          'consequence':
              'registering anyway — the token is still valid and delivery '
              'starts the moment notifications are turned on',
        });
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        AuthLogger.event('PUSH · no token yet', {
          'consequence': 'retried on the next resume',
        });
        return;
      }

      await _sendWithRetry(token);
    } catch (error) {
      AuthLogger.event('PUSH · could not register', {'reason': '$error'});
    }
  }

  /// Registers again if this device is not currently filed with the server.
  ///
  /// Cheap and safe to call as often as you like — it does nothing once the
  /// token is in. What it is for is the two cases a one-shot registration at
  /// launch cannot cover:
  ///
  ///  * The app started with no usable network. Phones routinely open before
  ///    wifi has settled, the POST fails, and under the old code that was the
  ///    end of it until the next cold start — which on a phone that is never
  ///    fully closed may be days.
  ///  * Somebody went to Settings, turned notifications on, and came back. The
  ///    resume is the only signal the app gets that anything changed.
  Future<void> syncDevice() async {
    if (_token != null) return;
    await registerDevice();
  }

  /// True once the server has confirmed it holds this device.
  bool get isRegistered => _token != null;

  /// Whether the rotation listener is attached. Guarded because
  /// [registerDevice] now runs on every launch as well as at sign-in, and a
  /// listener per call would mean one POST per launch per rotation.
  bool _listeningForRotation = false;

  /// How many times a registration is attempted before it waits for the next
  /// resume, and how long between tries.
  ///
  /// Short and few on purpose. This is not a queue that has to survive the
  /// process — [syncDevice] is, and it runs on every resume — so the retries
  /// only need to cover the seconds around launch when a phone has an
  /// interface up but no route yet.
  static const List<Duration> _retryBackoff = [
    Duration(seconds: 2),
    Duration(seconds: 8),
  ];

  Future<void> _sendWithRetry(String token) async {
    for (var attempt = 0; ; attempt++) {
      if (await _send(token)) return;

      if (attempt >= _retryBackoff.length) {
        AuthLogger.event('PUSH · giving up for now', {
          'consequence':
              'this handset cannot be reached until the next resume '
              'or launch, which will try again',
        });
        return;
      }

      await Future<void>.delayed(_retryBackoff[attempt]);
    }
  }

  /// One attempt. True when the server has it.
  Future<bool> _send(String token) async {
    try {
      await _client.post(
        '/devices',
        body: {
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
      );

      _token = token;
      AuthLogger.event('PUSH · device registered', {
        'token': '${token.substring(0, 12)}…',
      });
      return true;
    } catch (error) {
      // Not fatal and never worth interrupting a sign-in for: the app still
      // rings while it is open, and the caller retries.
      AuthLogger.event('PUSH · registration failed', {'reason': '$error'});
      return false;
    }
  }

  /// Forgets this device, so the next person to use the handset is not rung for
  /// the last person's consultations. Called on sign-out.
  Future<void> unregisterDevice() async {
    final token = _token;
    if (token == null) return;

    _token = null;
    try {
      await _client.delete('/devices/$token');
    } catch (_) {
      // The token is gone locally either way, and the server prunes tokens
      // Firebase reports as dead.
    }
  }
}
