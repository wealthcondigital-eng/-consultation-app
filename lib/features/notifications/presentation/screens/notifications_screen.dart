import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/format/app_date_format.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/app_notification.dart';
import '../controllers/notifications_controller.dart';
import '../../../../core/l10n/tr.dart';

/// Everything the app has told this user, newest first — drawn as a **pulse
/// timeline**.
///
/// A heartbeat strip at the top carries the unread count; below it a single
/// spine runs down the page, and every message is a beat on it: a node in the
/// colour of its kind, and the words beside it. Days are markers on the spine
/// itself rather than headings across the page, so the list reads as one
/// continuous record of care instead of a stack of cards.
///
/// The list only shows messages. Tapping one marks it read and goes nowhere.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsController _controller =
      sl<NotificationsController>();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.canvas,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        scrollable: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppTopBar(
                title: 'Notifications',
                variant: AppTopBarVariant.outlined,
              ),
              Expanded(child: _Body(controller: _controller)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (controller.isLoading && !controller.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage case final message?) {
      return Padding(
        padding: sizing.screenPadding,
        child: AppInlineError(message: message, onRetry: controller.load),
      );
    }

    if (controller.isEmpty) {
      return Padding(
        padding: sizing.screenPadding,
        child: const AppEmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'Nothing yet',
          message:
              'Booking confirmations and appointment reminders will appear '
              'here.',
        ),
      );
    }

    final notifications = controller.notifications;
    final now = DateTime.now();

    return AppRefreshIndicator(
      onRefresh: controller.load,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          sizing.screenPaddingH,
          sizing.spacingMd,
          sizing.screenPaddingH,
          sizing.spacingXxl,
        ),
        itemCount: notifications.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.only(bottom: sizing.spacingLg),
              child: _PulseHeader(
                unread: controller.unreadCount,
                total: notifications.length,
                onMarkAllRead: controller.hasUnread
                    ? controller.markAllRead
                    : null,
              ),
            );
          }

          final i = index - 1;
          final notification = notifications[i];
          final day = _dayOf(notification.sortKey, now);
          final startsDay =
              i == 0 || _dayOf(notifications[i - 1].sortKey, now) != day;

          return _Beat(
            notification: notification,
            dayMarker: startsDay ? day : null,
            isFirst: i == 0,
            isLast: i == notifications.length - 1,
            onTap: () => controller.open(notification),
          );
        },
      ),
    );
  }

  static String _dayOf(DateTime at, DateTime now) {
    if (AppDateFormat.isSameDay(at, now)) return tr('Today');
    if (AppDateFormat.isSameDay(at, now.subtract(const Duration(days: 1)))) {
      return tr('Yesterday');
    }
    return '${AppDateFormat.weekdayShort(at)}, ${AppDateFormat.dayMonth(at)}';
  }
}

/// The heartbeat strip: how many messages are new, over a live ECG trace.
class _PulseHeader extends StatefulWidget {
  const _PulseHeader({
    required this.unread,
    required this.total,
    required this.onMarkAllRead,
  });

  final int unread;
  final int total;
  final VoidCallback? onMarkAllRead;

  @override
  State<_PulseHeader> createState() => _PulseHeaderState();
}

class _PulseHeaderState extends State<_PulseHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  int _sweeps = 0;

  @override
  void initState() {
    super.initState();
    // A few sweeps when the screen opens, then still — a trace that never
    // stops is a distraction, and a battery cost for nothing.
    _beat.addStatusListener((status) {
      if (status == AnimationStatus.completed && ++_sweeps < 3) {
        _beat.forward(from: 0);
      }
    });
    _beat.forward();
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final hasNew = widget.unread > 0;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        gradient: AppColors.brandSweep,
        borderRadius: BorderRadius.circular(sizing.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.unread}',
                style: sizing.text.screenTitle.copyWith(
                  color: AppColors.onBrand,
                  fontSize: sizing.sp(40),
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: sizing.r(4)),
                  child: Text(
                    hasNew
                        ? (widget.unread == 1
                              ? tr('new update\nof {total} in your care feed', {
                                  'total': widget.total,
                                })
                              : tr(
                                  'new updates\nof {total} in your care feed',
                                  {'total': widget.total},
                                ))
                        : tr(
                            'You’re all caught up\n{total} in your care feed',
                            {'total': widget.total},
                          ),
                    style: sizing.text.metaLabel.copyWith(
                      color: AppColors.onBrandMuted,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              if (widget.onMarkAllRead case final onTap?)
                Material(
                  color: AppColors.onBrandSurface,
                  borderRadius: BorderRadius.circular(sizing.radiusPill),
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(sizing.radiusPill),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: sizing.spacingSm,
                        vertical: sizing.spacingXxs + 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.done_all_rounded,
                            size: sizing.iconXs,
                            color: AppColors.onBrand,
                          ),
                          SizedBox(width: sizing.spacingXxs),
                          Text(
                            tr('Read all'),
                            style: sizing.text.metaLabel.copyWith(
                              color: AppColors.onBrand,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: sizing.spacingSm),
          SizedBox(
            height: sizing.r(34),
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _beat,
              builder: (context, _) => CustomPaint(
                painter: _EcgPainter(
                  progress: _beat.value,
                  // Flat-lines when there is nothing new — the same trace,
                  // quieter.
                  amplitude: hasNew ? 1 : 0.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A heartbeat trace with a bright head sweeping across it.
class _EcgPainter extends CustomPainter {
  const _EcgPainter({required this.progress, required this.amplitude});

  final double progress;
  final double amplitude;

  /// One beat as (x, y) in a unit box — baseline, P wave, QRS spike, T wave.
  static const _beat = [
    Offset(0, 0.5),
    Offset(0.18, 0.5),
    Offset(0.24, 0.42),
    Offset(0.30, 0.5),
    Offset(0.38, 0.5),
    Offset(0.42, 0.62),
    Offset(0.47, 0.04),
    Offset(0.52, 0.86),
    Offset(0.56, 0.5),
    Offset(0.68, 0.5),
    Offset(0.76, 0.36),
    Offset(0.84, 0.5),
    Offset(1, 0.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const beats = 3;
    final beatWidth = size.width / beats;
    final path = Path();

    for (var b = 0; b < beats; b++) {
      for (final point in _beat) {
        final x = b * beatWidth + point.dx * beatWidth;
        final y = size.height / 2 + (point.dy - 0.5) * size.height * amplitude;
        if (b == 0 && point == _beat.first) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );

    // The bright head: the trace lit up just behind the sweep.
    final head = progress * size.width;
    final tail = math.max(0.0, head - size.width * 0.35);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(tail, 0, head, size.height));
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withValues(alpha: 0), Colors.white],
        ).createShader(Rect.fromLTRB(tail, 0, head, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EcgPainter old) =>
      old.progress != progress || old.amplitude != amplitude;
}

/// One notification: a node on the spine, and its words beside it.
class _Beat extends StatelessWidget {
  const _Beat({
    required this.notification,
    required this.dayMarker,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final AppNotification notification;

  /// Set on the first notification of a day: drawn as a tag on the spine.
  final String? dayMarker;

  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  (IconData, Color, Color, String) get _look => switch (notification.kind) {
    NotificationKind.bookingConfirmed => (
      Icons.event_available_rounded,
      AppColors.success,
      AppColors.successSurface,
      'Booking',
    ),
    NotificationKind.consultationReminder => (
      Icons.alarm_rounded,
      AppColors.warning,
      AppColors.warningSurface,
      'Reminder',
    ),
    NotificationKind.consultationStarting => (
      Icons.videocam_rounded,
      AppColors.primary,
      AppColors.primarySurface,
      'Starting',
    ),
    NotificationKind.general => (
      Icons.auto_awesome_rounded,
      AppColors.anonymousAccent.icon,
      AppColors.anonymousAccent.surface,
      'Update',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final (icon, tone, toneSurface, kindLabel) = _look;
    final unread = !notification.isRead;
    final node = sizing.r(34);
    final rail = node + sizing.spacingSm * 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dayMarker case final day?)
          _DayMarker(label: day, rail: rail, isFirst: isFirst),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The spine, and this beat's node on it.
              SizedBox(
                width: rail,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 0,
                      bottom: isLast ? null : 0,
                      height: isLast ? sizing.spacingMd : null,
                      child: Container(
                        width: sizing.r(2),
                        color: AppColors.border,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: sizing.spacingXs),
                      child: Container(
                        width: node,
                        height: node,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: unread ? tone : toneSurface,
                          border: Border.all(
                            color: AppColors.canvas,
                            width: sizing.r(3),
                          ),
                          boxShadow: unread
                              ? [
                                  BoxShadow(
                                    color: tone.withValues(alpha: 0.35),
                                    blurRadius: sizing.r(10),
                                    spreadRadius: sizing.r(1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          icon,
                          size: sizing.iconXs,
                          color: unread ? Colors.white : tone,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: sizing.spacingMd),
                  child: _Message(
                    notification: notification,
                    tone: tone,
                    kindLabel: kindLabel,
                    onTap: onTap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.notification,
    required this.tone,
    required this.kindLabel,
    required this.onTap,
  });

  final AppNotification notification;
  final Color tone;
  final String kindLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final unread = !notification.isRead;
    // A speech-bubble corner pointing back at the node on the spine.
    final radius = BorderRadius.only(
      topLeft: Radius.circular(sizing.r(4)),
      topRight: Radius.circular(sizing.radiusLg),
      bottomLeft: Radius.circular(sizing.radiusLg),
      bottomRight: Radius.circular(sizing.radiusLg),
    );

    return Material(
      color: unread ? AppColors.surface : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: unread ? onTap : null,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(sizing.spacingSm + 2),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              width: sizing.hairline,
              color: unread ? tone.withValues(alpha: 0.45) : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: tr(kindLabel).toUpperCase(),
                        style: sizing.text.badgeLabel.copyWith(
                          color: tone,
                          fontSize: sizing.sp(10),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '  ·  '
                                '${AppDateFormat.clockTime(notification.sortKey)}',
                            style: sizing.text.metaLabel.copyWith(
                              fontSize: sizing.sp(11),
                              color: AppColors.textTertiary,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (unread)
                    Text(
                      tr('NEW'),
                      style: sizing.text.badgeLabel.copyWith(
                        color: tone,
                        fontSize: sizing.sp(10),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                ],
              ),
              SizedBox(height: sizing.spacingXxs),
              Text(
                tr(notification.title),
                style: sizing.text.cardTitle.copyWith(
                  fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                  color: unread
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              SizedBox(height: sizing.spacingXxs),
              Text(
                tr(notification.body),
                style: sizing.text.cardBody.copyWith(
                  height: 1.45,
                  color: unread ? AppColors.textLabel : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `TODAY` — a tag sitting on the spine where a new day begins.
class _DayMarker extends StatelessWidget {
  const _DayMarker({
    required this.label,
    required this.rail,
    required this.isFirst,
  });

  final String label;
  final double rail;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return SizedBox(
      height: sizing.r(30),
      child: Row(
        children: [
          SizedBox(
            width: rail,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!isFirst)
                  Container(width: sizing.r(2), color: AppColors.border),
                Container(
                  width: sizing.r(10),
                  height: sizing.r(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.canvas,
                    border: Border.all(
                      color: AppColors.textTertiary,
                      width: sizing.r(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            label.toUpperCase(),
            style: sizing.text.metaLabel.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Container(height: sizing.hairline, color: AppColors.border),
          ),
        ],
      ),
    );
  }
}
