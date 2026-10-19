import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/appointment.dart';
import '../widgets/appointment_card.dart' show PaymentPill;

/// The fee receipt for one consultation, laid out as a bill.
///
/// A payment-app style confirmation on top — the outcome, the amount, who it
/// went to — and a ticket below it with the line items, the payment reference
/// and the doctor's registration number. It exists for two reasons:
///
/// - The NMC Telemedicine Practice Guidelines 2020 require a registered
///   practitioner's registration number to appear on the fee receipt.
/// - A patient querying a charge needs the gateway's transaction reference,
///   which is the only thing that ties this consultation to a line on their
///   bank statement.
///
/// Shareable two ways: the whole screen, or just the bill — somebody sending
/// it to an insurer or an employer wants the bill and nothing around it.
///
/// Built from the [Appointment] the list already holds rather than fetching
/// anything, so it opens instantly and works offline.
class ConsultationReceiptScreen extends StatefulWidget {
  const ConsultationReceiptScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  State<ConsultationReceiptScreen> createState() =>
      _ConsultationReceiptScreenState();
}

class _ConsultationReceiptScreenState extends State<ConsultationReceiptScreen> {
  final GlobalKey _screenKey = GlobalKey();
  final GlobalKey _billKey = GlobalKey();

  bool _isSharing = false;

  Appointment get _appointment => widget.appointment;

  /// Renders the widget under [key] to a PNG and hands it to the share sheet.
  Future<void> _shareImage(GlobalKey key, String name) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(2.0, 3.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;

      final file = XFile.fromData(
        data.buffer.asUint8List(),
        mimeType: 'image/png',
        name: '$name.png',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: ['$name.png'],
          subject: tr('Consultation receipt'),
          text: _shareCaption(),
        ),
      );
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'Could not share the receipt.');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _shareCaption() {
    final total = _appointment.totalLabel ?? '';
    return '${tr('Teleconsult receipt')} · ${_appointment.counterpartName} · '
        '$total · ${_appointment.whenLabel}';
  }

  String get _fileStem => 'receipt-${_appointment.id}';

  Future<void> _showShareOptions() async {
    final sizing = context.sizing;

    final choice = await showModalBottomSheet<_ShareChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(sizing.radiusLg),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            sizing.screenPaddingH,
            0,
            sizing.screenPaddingH,
            sizing.spacingMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Share receipt'), style: sizing.text.cardTitle),
              SizedBox(height: sizing.spacingSm),
              _ShareOption(
                icon: Icons.receipt_long_rounded,
                title: 'Share bill only',
                subtitle: 'Just the bill — for insurance or reimbursement',
                onTap: () => Navigator.of(context).pop(_ShareChoice.bill),
              ),
              _ShareOption(
                icon: Icons.screenshot_rounded,
                title: 'Share full screen',
                subtitle: 'Payment status and the bill together',
                onTap: () => Navigator.of(context).pop(_ShareChoice.screen),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;

    switch (choice) {
      case _ShareChoice.bill:
        await _shareImage(_billKey, '$_fileStem-bill');
      case _ShareChoice.screen:
        await _shareImage(_screenKey, _fileStem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTopBar(
              title: 'Receipt',
              variant: AppTopBarVariant.outlined,
              trailing: IconButton(
                tooltip: tr('Share'),
                onPressed: _isSharing ? null : _showShareOptions,
                icon: Icon(
                  Icons.share_rounded,
                  size: sizing.iconMd,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              // A single child rather than a lazy list, so the whole receipt
              // is laid out and painted — which is what lets it be captured
              // as one image even when part of it is scrolled off.
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: _screenKey,
                  child: ColoredBox(
                    color: AppColors.canvas,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        sizing.screenPaddingH,
                        sizing.spacingLg,
                        sizing.screenPaddingH,
                        sizing.spacingXl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _StatusHero(appointment: _appointment),
                          SizedBox(height: sizing.spacingLg),
                          RepaintBoundary(
                            key: _billKey,
                            child: _Bill(appointment: _appointment),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                sizing.screenPaddingH,
                sizing.spacingSm,
                sizing.screenPaddingH,
                sizing.spacingSm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton.outline(
                      label: 'Share bill',
                      leading: const Icon(Icons.receipt_long_rounded),
                      isLoading: false,
                      onPressed: _isSharing
                          ? null
                          : () => _shareImage(_billKey, '$_fileStem-bill'),
                    ),
                  ),
                  SizedBox(width: sizing.spacingSm),
                  Expanded(
                    child: AppButton.primary(
                      label: 'Share',
                      leading: const Icon(Icons.share_rounded),
                      isLoading: _isSharing,
                      onPressed: _isSharing ? null : _showShareOptions,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ShareChoice { bill, screen }

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: sizing.avatarSize,
        height: sizing.avatarSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: sizing.iconMd, color: AppColors.primary),
      ),
      title: Text(tr(title), style: sizing.text.cardTitle),
      subtitle: Text(tr(subtitle), style: sizing.text.cardSubtitle),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textTertiary,
      ),
    );
  }
}

/// The confirmation at the top — a big mark, the outcome, the amount and who
/// it went to, the way a payment app shows a completed transfer.
class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final status = appointment.effectivePaymentStatus;

    final (icon, color, title) = switch (status) {
      PaymentStatus.paid => (
        Icons.check_rounded,
        AppColors.successStrong,
        'Payment successful',
      ),
      PaymentStatus.failed => (
        Icons.close_rounded,
        AppColors.danger,
        'Payment failed',
      ),
      PaymentStatus.refunded => (
        Icons.replay_rounded,
        AppColors.warning,
        'Amount refunded',
      ),
      PaymentStatus.pending => (
        Icons.schedule_rounded,
        AppColors.textSecondary,
        'Payment pending',
      ),
      null => (Icons.receipt_long_rounded, AppColors.primary, 'Receipt'),
    };

    final paidAt = appointment.paidAt ?? appointment.occursAt;
    final amount =
        status == PaymentStatus.refunded && appointment.refundedAmount > 0
        ? '₹${appointment.refundedAmount}'
        : appointment.totalLabel ?? '—';

    return Column(
      children: [
        Container(
          width: sizing.r(68),
          height: sizing.r(68),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: sizing.r(18),
                spreadRadius: sizing.r(4),
              ),
            ],
          ),
          child: Icon(icon, size: sizing.r(40), color: Colors.white),
        ),
        SizedBox(height: sizing.spacingMd),
        Text(
          tr(title),
          style: sizing.text.cardTitle.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: sizing.spacingXs),
        Text(
          amount,
          style: sizing.text.screenTitle.copyWith(
            fontSize: sizing.sp(36),
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            decoration: status == PaymentStatus.failed
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        SizedBox(height: sizing.spacingXxs),
        Text(
          tr('to {name}', {'name': appointment.counterpartName}),
          style: sizing.text.bodySmall.copyWith(
            color: AppColors.textLabel,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: sizing.spacingXxs),
        Text(
          '${AppDateFormat.monthDayYear(paidAt)}, '
          '${AppDateFormat.clockTime(paidAt)}',
          style: sizing.text.metaLabel,
        ),
      ],
    );
  }
}

/// The ticket: the doctor, the consultation, the line items, the payment.
class _Bill extends StatelessWidget {
  const _Bill({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final payment = appointment.effectivePaymentStatus;
    final consultationFee = appointment.fee ?? 0;
    final platformFee =
        appointment.platformFee ??
        ((appointment.amountPaid ?? consultationFee) - consultationFee);
    final total = appointment.amountPaid ?? consultationFee + platformFee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(sizing.radiusLg),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand strip, so a shared bill says where it came from.
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: sizing.cardPadding,
                  vertical: sizing.spacingSm,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.brandSweep,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(sizing.radiusLg),
                  ),
                ),
                child: Row(
                  children: [
                    AppLogoMark(size: sizing.iconMd, color: AppColors.onBrand),
                    SizedBox(width: sizing.spacingXs),
                    Expanded(
                      child: Text(
                        'Teleconsult',
                        style: sizing.text.cardTitle.copyWith(
                          color: AppColors.onBrand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      tr('Consultation bill'),
                      style: sizing.text.metaLabel.copyWith(
                        color: AppColors.onBrandMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(sizing.cardPadding),
                child: _DoctorBlock(appointment: appointment),
              ),
              const _TicketCut(),
              Padding(
                padding: EdgeInsets.all(sizing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BlockTitle('Consultation details'),
                    _Line('Type', tr(appointment.kind.label)),
                    _Line('Mode', appointment.mode.callTypeLabel),
                    _Line('Date & time', appointment.whenLabel),
                    if (appointment.durationSeconds > 0)
                      _Line('Duration', appointment.durationLabel),
                    _Line(
                      'Consultation',
                      switch (appointment.status) {
                        AppointmentStatus.completed => tr('Done'),
                        AppointmentStatus.expired => tr('Not connected'),
                        final status => tr(status.label),
                      },
                      valueColor: switch (appointment.status.outcome) {
                        AppointmentOutcome.done => AppColors.success,
                        AppointmentOutcome.abandoned => AppColors.danger,
                        AppointmentOutcome.pending => AppColors.primaryDeep,
                      },
                    ),
                  ],
                ),
              ),
              const _TicketCut(),
              Padding(
                padding: EdgeInsets.all(sizing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BlockTitle('Bill summary'),
                    _Line('Consultation fee', '₹$consultationFee'),
                    if (platformFee > 0) _Line('Platform fee', '₹$platformFee'),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: sizing.spacingXs),
                      child: Container(
                        height: sizing.hairline,
                        color: AppColors.border,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            payment == PaymentStatus.failed
                                ? tr('Amount due')
                                : tr('Total paid'),
                            style: sizing.text.cardTitle.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '₹$total',
                          style: sizing.text.cardTitle.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: sizing.sp(18),
                          ),
                        ),
                      ],
                    ),
                    if (appointment.refundedAmount > 0) ...[
                      SizedBox(height: sizing.spacingXs),
                      _Line(
                        'Refunded',
                        '− ₹${appointment.refundedAmount}',
                        valueColor: AppColors.warning,
                      ),
                    ],
                  ],
                ),
              ),
              const _TicketCut(),
              Padding(
                padding: EdgeInsets.all(sizing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _BlockTitle('Payment details')),
                        if (payment != null) PaymentPill(status: payment),
                      ],
                    ),
                    if (appointment.paymentMethodLabel case final method?)
                      _Line('Paid via', method),
                    _Line(
                      'Transaction ID',
                      appointment.paymentId,
                      missingLabel: 'Not available',
                      copyable: true,
                    ),
                    _Line('Paid on', switch (appointment.paidAt) {
                      final at? =>
                        '${AppDateFormat.monthDayYear(at)} · '
                            '${AppDateFormat.clockTime(at)}',
                      null => null,
                    }),
                    _Line('Reference ID', appointment.id, copyable: true),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: sizing.cardPadding,
                  vertical: sizing.spacingSm,
                ),
                color: AppColors.surfaceMuted,
                child: Text(
                  tr(
                    'This is a receipt for a teleconsultation fee. It is not a '
                    'prescription and not a medical record.',
                  ),
                  style: sizing.text.metaLabel.copyWith(
                    height: 1.5,
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        // The torn edge at the foot of a printed receipt.
        SizedBox(
          height: sizing.r(10),
          child: CustomPaint(
            painter: _ZigZagPainter(color: AppColors.surfaceMuted),
          ),
        ),
      ],
    );
  }
}

class _DoctorBlock extends StatelessWidget {
  const _DoctorBlock({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final registration = appointment.counterpartRegistrationNumber;

    return Row(
      children: [
        RemoteAvatar(
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
              ),
              if (appointment.counterpartSubtitle.isNotEmpty)
                Text(
                  appointment.counterpartSubtitle,
                  style: sizing.text.cardSubtitle,
                ),
              SizedBox(height: sizing.spacingXxs / 2),
              // Named as missing rather than hidden — a receipt that silently
              // omits the registration number looks complete and is not.
              Text(
                registration == null || registration.trim().isEmpty
                    ? tr('Reg. No. not on record')
                    : tr('Reg. No. {number}', {'number': registration}),
                style: sizing.text.metaLabel.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlockTitle extends StatelessWidget {
  const _BlockTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.only(bottom: sizing.spacingXs),
      child: Text(
        tr(title).toUpperCase(),
        style: sizing.text.metaLabel.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// One label-and-value line.
///
/// A null [value] still renders, showing [missingLabel]. A receipt with rows
/// quietly missing is one nobody can tell is incomplete.
class _Line extends StatelessWidget {
  const _Line(
    this.label,
    this.value, {
    this.missingLabel = '—',
    this.copyable = false,
    this.valueColor,
  });

  final String label;
  final String? value;
  final String missingLabel;
  final Color? valueColor;

  /// Long opaque strings — the transaction id, the consultation reference — are
  /// quoted to a bank or to support, and retyping one off a screen is how a
  /// digit gets lost.
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final shown = value;
    final present = shown != null && shown.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: sizing.spacingXxs + 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              tr(label),
              style: sizing.text.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              present ? shown : tr(missingLabel),
              textAlign: TextAlign.right,
              style: present
                  ? sizing.text.bodySmall.copyWith(
                      color: valueColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    )
                  : sizing.text.fieldPlaceholder,
            ),
          ),
          if (copyable && present) ...[
            SizedBox(width: sizing.spacingXs),
            InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: shown));
                if (context.mounted) {
                  AppSnackBar.info(
                    context,
                    tr('{label} copied', {'label': tr(label)}),
                  );
                }
              },
              child: Icon(
                Icons.copy_rounded,
                size: sizing.iconXs,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A dashed line with a half-circle notch at each end — the perforation
/// between two parts of a ticket.
class _TicketCut extends StatelessWidget {
  const _TicketCut();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final notch = sizing.r(9);

    return SizedBox(
      height: notch * 2,
      child: Row(
        children: [
          SizedBox(
            width: notch,
            height: notch * 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(100),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: sizing.spacingXs),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dash = sizing.r(6);
                  final count = (constraints.maxWidth / (dash * 2)).floor();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < count; i++)
                        SizedBox(
                          width: dash,
                          height: sizing.r(1.2),
                          child: ColoredBox(color: AppColors.border),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          SizedBox(
            width: notch,
            height: notch * 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(100),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZigZagPainter extends CustomPainter {
  const _ZigZagPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final tooth = size.height;
    final count = (size.width / (tooth * 2)).ceil();
    final step = size.width / count;
    final path = Path()..moveTo(0, 0);

    for (var i = 0; i < count; i++) {
      path
        ..lineTo(i * step + step / 2, size.height)
        ..lineTo((i + 1) * step, 0);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ZigZagPainter oldDelegate) => oldDelegate.color != color;
}
