import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/payment_failure.dart';

/// What the patient chose on the outcome screen, handed back to whoever opened
/// it.
///
/// Returned rather than acted on here, because only the caller knows what
/// "again" means: the payment screen re-opens checkout, and nothing else has a
/// checkout to re-open.
enum PaymentFailureChoice {
  /// Open checkout again.
  retry,

  /// Step back out of the booking — to the doctor, or the time picker.
  back,
}

/// What the outcome screen is showing.
class PaymentFailedArgs {
  const PaymentFailedArgs({
    required this.reason,
    required this.doctorName,
    this.formattedTotal,
    this.detail,
    this.isScheduled = false,
  });

  final PaymentFailureReason reason;

  final String doctorName;

  /// `₹750`, when there is an amount worth naming. The refund copy uses it:
  /// "₹750 is on its way back" is a sentence a person can check against a
  /// statement, and "your payment" is not.
  final String? formattedTotal;

  /// What the gateway or the server said, where it said something useful — a
  /// bank's decline reason, typically. Shown under the explanation, never
  /// instead of it: a raw gateway message on its own tells a patient what
  /// failed and nothing about what to do.
  final String? detail;

  /// True for a booked slot, which changes where Back goes and what a failure
  /// means for the time they picked.
  final bool isScheduled;
}

/// A booking that did not go through, and exactly what that means.
///
/// Replaces the snackbar the payment flow used to show, which was the wrong
/// size for the news. A failed payment is the moment a patient most needs to
/// know two things — **has money left my account, and what do I do now** — and
/// a strip of text that disappears after four seconds answered neither. It sat
/// over the payment summary with the Pay button still live, so the natural
/// reading was "try again", including in the one case where trying again is
/// how you get charged twice.
///
/// **Nothing moves forward from here.** Every path out leads back — to
/// checkout, to the doctor, to the time picker or to home. There is no route
/// from this screen into a consultation, a confirmation or a call.
class PaymentFailedScreen extends StatelessWidget {
  const PaymentFailedScreen({super.key, required this.args});

  final PaymentFailedArgs args;

  PaymentFailureReason get _reason => args.reason;

  void _home(BuildContext context) {
    Navigator.of(context).popUntil(
      (route) => route.settings.name == AppRoutes.home || route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final copy = _Copy.of(args);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: PopScope(
        // A back gesture means "step back out", never "try again" — the
        // gesture is not a decision to spend money.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _leave(context);
        },
        child: ResponsivePage(
          scrollable: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: sizing.screenPadding,
                  child: Column(
                    children: [
                      SizedBox(height: sizing.spacingXxl),
                      _Glyph(reason: _reason),
                      SizedBox(height: sizing.spacingXl),
                      Text(
                        copy.title,
                        style: sizing.text.screenTitleCompact,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: sizing.spacingXs),
                      Text(
                        copy.body,
                        style: sizing.text.helperText,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: sizing.spacingLg),
                      _MoneyPanel(
                        isCharged: _reason.isCharged,
                        text: copy.money,
                      ),
                      if (args.detail case final detail?
                          when detail.trim().isNotEmpty &&
                              _reason == PaymentFailureReason.declined) ...[
                        SizedBox(height: sizing.spacingSm),
                        Text(
                          tr(detail),
                          style: sizing.text.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: sizing.screenPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_reason.canRetry) ...[
                      AppButton.primary(
                        label: 'Try again',
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(PaymentFailureChoice.retry),
                      ),
                      SizedBox(height: sizing.spacingXs),
                      AppButton.secondary(
                        label: copy.backLabel,
                        onPressed: () => _leave(context),
                      ),
                    ] else
                      AppButton.primary(
                        label: copy.backLabel,
                        onPressed: () => _leave(context),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Where "back" goes depends on what failed.
  ///
  /// A payment problem goes back one step, to the doctor or the time picker,
  /// so the patient is where they were before they tapped Pay. A consultation
  /// that was paid for and then never happened goes home: the booking is over,
  /// and the screens behind it belong to a flow that has ended.
  void _leave(BuildContext context) {
    switch (_reason) {
      case PaymentFailureReason.noDoctor:
      case PaymentFailureReason.withdrawn:
      case PaymentFailureReason.unconfirmed:
        _home(context);
      case PaymentFailureReason.cancelled:
      case PaymentFailureReason.declined:
      case PaymentFailureReason.slotUnavailable:
        Navigator.of(context).pop(PaymentFailureChoice.back);
    }
  }
}

/// The words for one outcome, kept together so the title, the explanation and
/// the money line cannot disagree about what happened.
class _Copy {
  const _Copy({
    required this.title,
    required this.body,
    required this.money,
    required this.backLabel,
  });

  final String title;
  final String body;

  /// The sentence about money. Always present, because it is the question.
  final String money;

  final String backLabel;

  static _Copy of(PaymentFailedArgs args) {
    final amount = args.formattedTotal;
    final doctor = args.doctorName;

    return switch (args.reason) {
      PaymentFailureReason.cancelled => _Copy(
        title: tr('Payment cancelled'),
        body: tr(
          'You closed the payment before it finished, so nothing has been '
          'booked with {doctor}.',
          {'doctor': doctor},
        ),
        money: tr('You have not been charged.'),
        backLabel: args.isScheduled ? 'Choose another time' : 'Back to doctor',
      ),
      PaymentFailureReason.declined => _Copy(
        title: tr('Payment failed'),
        body: tr(
          'The payment did not go through, so nothing has been booked with '
          '{doctor}. You can try again, or use a different card or UPI app.',
          {'doctor': doctor},
        ),
        money: tr(
          'You have not been charged. If your bank shows a pending amount, '
          'it is released automatically within a few days.',
        ),
        backLabel: args.isScheduled ? 'Choose another time' : 'Back to doctor',
      ),
      PaymentFailureReason.unconfirmed => _Copy(
        title: tr('We could not confirm your payment'),
        body: tr(
          'Your payment may have gone through, but we could not confirm it. '
          'Please do not pay again — check My Appointments in a few minutes.',
        ),
        money: tr(
          'If {amount} left your account and no booking appears, '
          'it is refunded automatically to your original payment method.',
          {'amount': amount ?? tr('money')},
        ),
        backLabel: 'Back to home',
      ),
      PaymentFailureReason.slotUnavailable => _Copy(
        title: tr('That time has just been booked'),
        body: tr(
          'Someone booked this slot with {doctor} a moment before you. '
          'Please pick another time.',
          {'doctor': doctor},
        ),
        money: tr('You have not been charged.'),
        backLabel: 'Choose another time',
      ),
      PaymentFailureReason.noDoctor => _Copy(
        title: tr('No doctor was available'),
        body: tr(
          '{doctor} could not take your consultation just now, so it has '
          'been cancelled.',
          {'doctor': doctor},
        ),
        money: tr(
          '{amount} is being refunded to your original '
          'payment method. Refunds usually arrive in 5–7 working days.',
          {'amount': amount ?? tr('Your payment')},
        ),
        backLabel: 'Back to home',
      ),
      PaymentFailureReason.withdrawn => _Copy(
        title: tr('Consultation cancelled'),
        body: tr(
          'You cancelled before a doctor answered, so the consultation did '
          'not take place.',
        ),
        money: tr(
          '{amount} is being refunded to your original '
          'payment method. Refunds usually arrive in 5–7 working days.',
          {'amount': amount ?? tr('Your payment')},
        ),
        backLabel: 'Back to home',
      ),
    };
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.reason});

  final PaymentFailureReason reason;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    // A cancelled payment is a decision, not an error, and colouring it red
    // tells someone who simply changed their mind that something went wrong.
    // Amber for the cases that need attention, red only for an actual refusal.
    final (surface, foreground, icon) = switch (reason) {
      PaymentFailureReason.cancelled => (
        AppColors.surfaceMuted,
        AppColors.textSecondary,
        Icons.close_rounded,
      ),
      PaymentFailureReason.declined => (
        AppColors.dangerSurface,
        AppColors.danger,
        Icons.credit_card_off_rounded,
      ),
      PaymentFailureReason.unconfirmed => (
        AppColors.warningSurface,
        AppColors.warning,
        Icons.hourglass_top_rounded,
      ),
      PaymentFailureReason.slotUnavailable => (
        AppColors.warningSurface,
        AppColors.warning,
        Icons.event_busy_rounded,
      ),
      PaymentFailureReason.noDoctor || PaymentFailureReason.withdrawn => (
        AppColors.warningSurface,
        AppColors.warning,
        Icons.person_off_rounded,
      ),
    };

    return Container(
      width: sizing.r(96),
      height: sizing.r(96),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
      child: Icon(icon, size: sizing.r(44), color: foreground),
    );
  }
}

/// The answer to "has money left my account?", set apart so it cannot be
/// missed.
///
/// Green when nothing was charged — that is the reassuring answer and it
/// should look like one. Neutral when money is on its way back, because that
/// is information to keep rather than a problem to act on.
class _MoneyPanel extends StatelessWidget {
  const _MoneyPanel({required this.isCharged, required this.text});

  final bool isCharged;
  final String text;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: isCharged ? AppColors.surfaceMuted : AppColors.successSurface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCharged
                ? Icons.currency_rupee_rounded
                : Icons.verified_user_outlined,
            size: sizing.iconSm,
            color: isCharged ? AppColors.textSecondary : AppColors.success,
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(child: Text(text, style: sizing.text.bodySmall)),
        ],
      ),
    );
  }
}
