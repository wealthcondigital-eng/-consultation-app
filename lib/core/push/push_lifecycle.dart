import 'package:flutter/widgets.dart';

import '../di/service_locator.dart';
import '../recording/recording_upload_queue.dart';
import '../session/auth_session.dart';
import 'call_kit_bridge.dart';
import 'push_service.dart';

/// Re-files this handset with the server whenever the app comes back to the
/// foreground and it is not already filed.
///
/// Registering once at launch sounds sufficient and is not, and the gap it
/// leaves is the one that left a doctor unreachable. Two ordinary things defeat
/// a one-shot registration:
///
///  * **The launch had no network.** A phone opens an app before wifi has
///    finished associating far more often than not. The POST fails, and with
///    nothing watching, the next attempt is the next cold start — which on a
///    phone that is never fully closed can be days away.
///  * **Permission was granted later.** Somebody taps "Don't allow", finds out
///    the hard way that they missed a consultation, and turns notifications on
///    in Settings. Coming back to the app is the only signal it gets that
///    anything changed.
///
/// Costs nothing when there is nothing to do: [PushService.syncDevice] returns
/// immediately once the token is in.
class PushLifecycleObserver with WidgetsBindingObserver {
  /// Starts watching. Idempotent — binding observers are a set.
  void start() => WidgetsBinding.instance.addObserver(this);

  void stop() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // Only for a signed-in user. The token is filed against a person, so
    // registering without one would 401, and a retry loop against a route that
    // will keep saying no is just noise in the log.
    if (!sl<AuthSession>().isSignedIn) return;

    // An Accept on the ringing screen brings the app forward from the
    // background. Usually the event says so directly; this catches the one
    // that landed while nothing was listening.
    sl<CallKitBridge>().recoverSoon();

    // Deliberately not awaited: a lifecycle callback that blocks is a frame
    // that does not render, and nothing here needs to finish before the app is
    // usable again.
    sl<PushService>().syncDevice();

    // Back in the foreground is also when a recording that stalled on a
    // dropped connection gets another go. One drain at a time; a no-op when
    // nothing is pending.
    if (sl.isRegistered<RecordingUploadQueue>()) {
      sl<RecordingUploadQueue>().drain();
    }
  }
}
