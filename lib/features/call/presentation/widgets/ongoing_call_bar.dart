import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../domain/entities/call_session.dart';
import '../controllers/active_call.dart';

/// The green bar across the top of every screen while a consultation is under
/// way somewhere else — who it is with, how long it has run, and one tap back
/// to it. The same thing WhatsApp and the phone's own dialler show.
///
/// Wraps the whole app, above the navigator. While a call is away it takes
/// its height off the top, so no screen draws underneath it; otherwise it is
/// nothing at all.
class OngoingCallBar extends StatelessWidget {
  const OngoingCallBar({
    super.key,
    required this.activeCall,
    required this.onReturn,
    required this.child,
  });

  final ActiveCall activeCall;

  /// Opens the call screen onto the call in progress.
  final VoidCallback onReturn;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: activeCall,
      builder: (context, _) {
        // The same shape whether or not the bar shows, so the app beneath is
        // never re-parented — only the bar comes and goes.
        final away = activeCall.isAway;
        final controller = activeCall.controller;
        final args = activeCall.args;
        final media = MediaQuery.of(context);

        return Column(
          children: [
            if (away && controller != null && args != null)
              Material(
                color: const Color(0xFF16A34A),
                child: InkWell(
                  onTap: onReturn,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      media.padding.top + 6,
                      16,
                      8,
                    ),
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) {
                        final connected =
                            controller.state == CallState.connected;
                        final status = switch (controller.state) {
                          CallState.connected => controller.formattedDuration,
                          CallState.reconnecting => tr('Reconnecting…'),
                          _ => tr('Connecting…'),
                        };

                        return Row(
                          children: [
                            Icon(
                              args.mode == ConsultationMode.video
                                  ? Icons.videocam_rounded
                                  : Icons.call_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tr('Tap to return to call'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                args.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              status,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: connected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 14,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            // The bar has taken the status-bar inset; the screens below start
            // under it rather than leaving a second gap for the status bar.
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: away,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
