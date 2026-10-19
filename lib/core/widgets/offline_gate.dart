import 'package:flutter/material.dart';

import '../network/connectivity_monitor.dart';
import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import 'app_button.dart';
import '../l10n/tr.dart';

/// Covers the app while the backend cannot be reached.
///
/// An overlay rather than a route, and that is the whole design. Pushing an
/// offline screen would mean deciding what to do with the stack underneath —
/// and then deciding where to send the user when the connection returns, which
/// is a question with no good answer: anywhere but the screen they were on is
/// wrong, and that screen's state is gone by then anyway. Laid over the top,
/// nothing is unmounted; half-typed forms, scroll positions and open dialogs
/// are all still there when it lifts, so "landing back" costs nothing and can
/// never land somewhere unexpected.
///
/// Installed once, above the navigator, for the same reason the session gate
/// is: losing the connection is not one screen's problem.
class OfflineGate extends StatefulWidget {
  const OfflineGate({super.key, required this.monitor, required this.child});

  final ConnectivityMonitor monitor;
  final Widget child;

  @override
  State<OfflineGate> createState() => _OfflineGateState();
}

class _OfflineGateState extends State<OfflineGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    widget.monitor.addListener(_onChanged);
    // The monitor cannot read a failed request as an outage without knowing
    // whether the app was in front of the user at the time, and this is where
    // that is knowable: mounted above the navigator, so it outlives every route
    // and cannot miss a resume the way a screen would.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.monitor.removeListener(_onChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.monitor.onLifecycleChanged(state);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.monitor.isOffline)
          OfflineScreen(onRetry: widget.monitor.checkNow),
      ],
    );
  }
}

/// What the user sees while there is no way through to the server.
class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key, required this.onRetry});

  /// Probes immediately. The screen takes itself down when the probe — or the
  /// retry running behind it — succeeds, so this reports only whether the user
  /// has to keep waiting.
  final Future<bool> Function() onRetry;

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _isChecking = false;

  Future<void> _retry() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    final reachable = await widget.onRetry();
    // A successful probe removes this widget from the tree, so there is nothing
    // left to update — and a failed one leaves the screen up, which is already
    // the message.
    if (!mounted || reachable) return;

    setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: sizing.contentMaxWidth),
            child: Padding(
              padding: sizing.screenPadding,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: sizing.brandBadgeSizeHero,
                    height: sizing.brandBadgeSizeHero,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: sizing.brandMarkSizeHero,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: sizing.spacingXxl),
                  Text(
                    tr('No internet connection'),
                    style: sizing.text.screenTitleCompact,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: sizing.spacingSm),
                  Text(
                    // Says what was actually checked. "Check your connection"
                    // is unhelpful advice to someone whose phone is showing
                    // full Wi-Fi bars — which is the usual way this screen is
                    // reached.
                    tr(
                      'We could not reach the server. Your device may be '
                      'connected to a network that has no internet access.',
                    ),
                    style: sizing.text.leadParagraph,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: sizing.spacingXxl),
                  AppButton.primary(
                    label: 'Try again',
                    isLoading: _isChecking,
                    onPressed: _retry,
                  ),
                  SizedBox(height: sizing.spacingMd),
                  Text(
                    // The retry loop is running regardless, so a user who fixes
                    // their wifi and looks back at the phone finds the app
                    // already where they left it.
                    tr('This will clear on its own once you are back online.'),
                    style: sizing.text.legalFootnote,
                    textAlign: TextAlign.center,
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
