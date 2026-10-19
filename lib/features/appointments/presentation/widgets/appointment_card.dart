import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../domain/entities/appointment.dart';

/// One consultation on the appointment list.
///
/// The same card on both lists. It names [Appointment.counterpartName], which
/// on a patient's list is the doctor and on a doctor's list is the patient —
/// there is no branch here on who is looking, which is what stops the doctor's
/// list from showing the doctor.
///
/// Laid out so the two questions a patient opens this list with are answered
/// without reading: **did it happen** (the coloured stripe and the status line)
/// and **was I charged** (the payment pill in the footer).
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onRejoin,
    this.onViewReceipt,
    this.onTap,
  });

  final Appointment appointment;

  /// Shown only when the consultation could still be joined. Null on a list
  /// that has nowhere to send the person — a completed row is a record.
  final VoidCallback? onRejoin;

  /// Opens the fee receipt. Null on a list with nowhere to send the person, and
  /// the button stays hidden on a row that was never charged.
  final VoidCallback? onViewReceipt;

  /// The whole card, when it leads somewhere. Falls back to [onViewReceipt].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final onRejoin = this.onRejoin;
    final showRejoin = onRejoin != null && appointment.isRejoinable;
    final showReceipt =
        !showRejoin && onViewReceipt != null && appointment.hasReceipt;
    final tone = _StatusTone.of(appointment.status);
    final radius = BorderRadius.circular(sizing.radiusLg);
    final tap = onTap ?? (showReceipt ? onViewReceipt : null);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tap,
          // A Stack rather than IntrinsicHeight around a Row: the dashed
          // divider is a LayoutBuilder, which cannot report intrinsic sizes,
          // and asking it to blanked the whole home screen.
          child: Stack(
            children: [
              // The outcome at a glance, before a word is read.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: sizing.r(4),
                child: ColoredBox(color: tone.accent),
              ),
              Padding(
                padding: EdgeInsets.only(left: sizing.r(4)),
                child: Padding(
                  padding: EdgeInsets.all(sizing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(appointment: appointment, tone: tone),
                      SizedBox(height: sizing.spacingSm),
                      _WhenStrip(appointment: appointment),
                      // What the consultation was about, in the patient's
                      // own words — what makes one past consultation
                      // tellable from another.
                      if (appointment.concern case final concern?) ...[
                        SizedBox(height: sizing.spacingXs),
                        Text(
                          '“$concern”',
                          style: sizing.text.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: sizing.spacingSm),
                      _DashedDivider(),
                      SizedBox(height: sizing.spacingSm),
                      _Footer(
                        appointment: appointment,
                        showReceipt: showReceipt,
                      ),
                      if (showRejoin) ...[
                        SizedBox(height: sizing.spacingSm),
                        _RejoinButton(onTap: onRejoin),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colours and words for where a consultation ended up.
class _StatusTone {
  const _StatusTone({
    required this.label,
    required this.icon,
    required this.accent,
    required this.surface,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final Color surface;

  static _StatusTone of(AppointmentStatus status) => switch (status) {
    AppointmentStatus.completed => _StatusTone(
      label: 'Consultation done',
      icon: Icons.check_circle_rounded,
      accent: AppColors.success,
      surface: AppColors.successSurface,
    ),
    AppointmentStatus.cancelled => _StatusTone(
      label: 'Cancelled',
      icon: Icons.cancel_rounded,
      accent: AppColors.danger,
      surface: AppColors.dangerSurface,
    ),
    AppointmentStatus.expired => _StatusTone(
      label: 'Not connected',
      icon: Icons.phone_missed_rounded,
      accent: AppColors.warning,
      surface: AppColors.warningSurface,
    ),
    AppointmentStatus.scheduled => _StatusTone(
      label: 'Confirmed',
      icon: Icons.event_available_rounded,
      accent: AppColors.primary,
      surface: AppColors.primarySurface,
    ),
    AppointmentStatus.inProgress => _StatusTone(
      label: 'In progress',
      icon: Icons.videocam_rounded,
      accent: AppColors.primary,
      surface: AppColors.primarySurface,
    ),
    _ => _StatusTone(
      label: status.label,
      icon: Icons.hourglass_top_rounded,
      accent: AppColors.primary,
      surface: AppColors.primarySurface,
    ),
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.appointment, required this.tone});

  final Appointment appointment;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RemoteAvatar(
          // No photo on a history row. The list is read at a glance and a
          // screenful of authenticated image requests to render forty pixels
          // each is a cost with nothing to show for it.
          path: null,
          initials: appointment.isAnonymous
              ? '?'
              : initialsOf(appointment.counterpartName),
          size: sizing.avatarSize,
          semanticLabel: appointment.counterpartName,
        ),
        SizedBox(width: sizing.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.counterpartName,
                style: sizing.text.cardTitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (appointment.counterpartSubtitle.isNotEmpty) ...[
                SizedBox(height: sizing.spacingXxs / 2),
                Text(
                  appointment.counterpartSubtitle,
                  style: sizing.text.cardSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: sizing.spacingXxs),
              Row(
                children: [
                  Icon(tone.icon, size: sizing.iconXs, color: tone.accent),
                  SizedBox(width: sizing.spacingXxs),
                  Flexible(
                    child: Text(
                      tr(tone.label),
                      style: sizing.text.metaLabel.copyWith(
                        color: tone.accent,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        _KindBadge(kind: appointment.kind),
      ],
    );
  }
}

/// `Instant` / `Scheduled`, in the corner where the eye lands second.
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final AppointmentKind kind;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final isInstant = kind == AppointmentKind.instant;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingXs,
        vertical: sizing.spacingXxs / 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusPill),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isInstant ? Icons.bolt_rounded : Icons.event_rounded,
            size: sizing.iconXs * 0.85,
            color: AppColors.primary,
          ),
          SizedBox(width: sizing.spacingXxs / 2),
          Text(
            tr(kind.shortLabel),
            style: sizing.text.badgeLabel.copyWith(
              fontSize: sizing.sp(11),
              color: AppColors.textLabel,
            ),
          ),
        ],
      ),
    );
  }
}

/// When, how, and for how long — one tinted strip.
class _WhenStrip extends StatelessWidget {
  const _WhenStrip({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final upcoming = appointment.isUpcoming();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingSm,
        vertical: sizing.spacingXs,
      ),
      decoration: BoxDecoration(
        color: upcoming ? AppColors.primarySurface : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: sizing.iconXs * 0.85,
            color: upcoming ? AppColors.primaryDeep : AppColors.textSecondary,
          ),
          SizedBox(width: sizing.spacingXxs),
          Expanded(
            child: Text(
              // `Tomorrow · 9:00 AM`, `Yesterday · 4:15 PM`, and a full date
              // for anything further out either way.
              appointment.relativeWhenLabel(),
              style: sizing.text.metaLabel.copyWith(
                color: upcoming ? AppColors.primaryDeep : AppColors.textLabel,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            appointment.mode.name == 'audio'
                ? Icons.call_rounded
                : Icons.videocam_rounded,
            size: sizing.iconXs * 0.85,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: sizing.spacingXxs / 2),
          Text(
            appointment.durationSeconds > 0
                ? '${tr(appointment.mode.shortLabel)} · ${appointment.durationLabel}'
                : tr(appointment.mode.shortLabel),
            style: sizing.text.metaLabel.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The money and the rating on the left, the receipt link on the right.
class _Footer extends StatelessWidget {
  const _Footer({required this.appointment, required this.showReceipt});

  final Appointment appointment;
  final bool showReceipt;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final payment = appointment.effectivePaymentStatus;

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: sizing.spacingXs,
            runSpacing: sizing.spacingXxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (appointment.totalLabel case final total?)
                Text(
                  total,
                  style: sizing.text.cardTitle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (payment != null) PaymentPill(status: payment),
              if (appointment.rating case final rating?)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: sizing.iconXs,
                      color: AppColors.ratingStar,
                    ),
                    Text(
                      '$rating.0',
                      style: sizing.text.metaLabel.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              if (appointment.totalLabel == null && payment == null)
                Text(
                  tr('No charge'),
                  style: sizing.text.metaLabel.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
        if (showReceipt) ...[
          SizedBox(width: sizing.spacingXs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: sizing.iconXs,
                color: AppColors.primary,
              ),
              SizedBox(width: sizing.spacingXxs / 2),
              Text(
                tr('View bill'),
                style: sizing.text.sectionAction.copyWith(
                  fontSize: sizing.sp(12),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: sizing.iconSm,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// `✓ Paid` / `✕ Payment failed` / `↺ Refunded` — shared with the bill.
class PaymentPill extends StatelessWidget {
  const PaymentPill({super.key, required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final (icon, color, surface) = switch (status) {
      PaymentStatus.paid => (
        Icons.check_rounded,
        AppColors.success,
        AppColors.successSurface,
      ),
      PaymentStatus.failed => (
        Icons.close_rounded,
        AppColors.danger,
        AppColors.dangerSurface,
      ),
      PaymentStatus.refunded => (
        Icons.replay_rounded,
        AppColors.warning,
        AppColors.warningSurface,
      ),
      PaymentStatus.pending => (
        Icons.schedule_rounded,
        AppColors.textSecondary,
        AppColors.surfaceMuted,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingXs,
        vertical: sizing.spacingXxs / 2,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(sizing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: sizing.iconXs * 0.8, color: color),
          SizedBox(width: sizing.spacingXxs / 2),
          Text(
            tr(status.label),
            style: sizing.text.badgeLabel.copyWith(
              fontSize: sizing.sp(11),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dash = sizing.r(5);
        final count = (constraints.maxWidth / (dash * 2)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(
                width: dash,
                height: sizing.hairline,
                child: ColoredBox(color: AppColors.border),
              ),
          ],
        );
      },
    );
  }
}

class _RejoinButton extends StatelessWidget {
  const _RejoinButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return SizedBox(
      height: sizing.buttonHeightCompact,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sizing.radiusMd),
          ),
        ),
        icon: Icon(Icons.login_rounded, size: sizing.iconXs),
        label: Text(tr('Rejoin call'), style: sizing.text.buttonLabelCompact),
      ),
    );
  }
}
