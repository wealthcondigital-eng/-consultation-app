import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/push/appointment_push.dart';
import '../../../../core/push/push_service.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/notifications_controller.dart';
import '../../../../core/l10n/tr.dart';

/// The way into the notifications page, with a dot when something is waiting.
///
/// Owns a controller of its own rather than reading one from the screen it sits
/// on: the bell appears on a dashboard that knows nothing about notifications,
/// and threading the state through every screen that wants one would put a
/// notifications dependency on all of them.
///
/// Reloads when it comes back into view, so booking a slot and returning to the
/// dashboard shows the dot without a restart.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.onBrand = true});

  /// True on the gradient header, false on a white surface.
  final bool onBrand;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver, RouteAware {
  late final NotificationsController _controller =
      sl<NotificationsController>();

  StreamSubscription<AppointmentPush>? _pushes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.load();

    // A reminder that lands while the app is already open. The resume hook
    // below never fires for it — nobody left the app — so without this the dot
    // would stay off until the next time they did, which for a "starting in two
    // minutes" is well past the point of it.
    _pushes = PushService.appointments.listen((_) => _controller.load());
  }

  @override
  void dispose() {
    _pushes?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A reminder comes due while the phone is in a pocket. Coming back to the
    // app is the moment to find out.
    if (state == AppLifecycleState.resumed) _controller.load();
  }

  Future<void> _open() async {
    await Navigator.of(context).pushNamed(AppRoutes.notifications);
    if (!mounted) return;

    // Whatever was read in there changes the dot out here.
    await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final foreground = widget.onBrand
        ? AppColors.onBrand
        : AppColors.textPrimary;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Semantics(
          button: true,
          label: _controller.hasUnread
              ? tr('Notifications, {count} unread', {
                  'count': _controller.unreadCount,
                })
              : tr('Notifications'),
          excludeSemantics: true,
          child: InkWell(
            onTap: _open,
            customBorder: const CircleBorder(),
            child: Container(
              width: sizing.avatarSize,
              height: sizing.avatarSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.onBrand
                    ? AppColors.onBrandSurface
                    : AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: sizing.iconSm,
                    color: foreground,
                  ),
                  if (_controller.hasUnread)
                    Positioned(
                      top: sizing.r(6),
                      right: sizing.r(6),
                      // A dot rather than a count. The number is on the page
                      // itself, and a badge reading "12" on a health app is a
                      // pressure the content rarely justifies.
                      child: Container(
                        width: sizing.r(9),
                        height: sizing.r(9),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: sizing.r(1.5),
                            color: widget.onBrand
                                ? AppColors.primary
                                : AppColors.surface,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
