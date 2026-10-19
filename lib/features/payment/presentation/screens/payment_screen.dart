import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../anonymous/domain/entities/anonymous_session.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/payment_failure.dart';
import '../../domain/entities/payment_method.dart';
import '../controllers/payment_controller.dart';
import '../widgets/fee_breakdown_card.dart';
import '../widgets/payment_doctor_card.dart';
import '../widgets/payment_method_tile.dart';
import '../widgets/upi_details.dart';
import 'payment_failed_screen.dart';
import 'payment_success_screen.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Who the patient is paying, and for which kind of consultation.
class PaymentArgs {
  const PaymentArgs({
    required this.doctor,
    this.mode = ConsultationMode.video,
    this.scheduledFor,
    this.scheduledAt,
    this.anonymousSession,
  });

  final Doctor doctor;
  final ConsultationMode mode;

  /// The booked day and time as a sentence, e.g. `Mon, 18 Aug at 10:30 AM`.
  /// Null for a consultation that starts as soon as it is paid for.
  final String? scheduledFor;

  /// The same moment, as a moment.
  ///
  /// This is what gets booked; [scheduledFor] is only what gets read. The flow
  /// used to carry the sentence alone, which is precisely why no appointment
  /// was ever filed — there was nothing in it a server could store.
  final DateTime? scheduledAt;

  /// Set when the patient is booking under an alias.
  final AnonymousSession? anonymousSession;
}

/// Review the charge and pay for a consultation.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.args});

  final PaymentArgs args;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final PaymentController _controller = sl<PaymentController>();
  final TextEditingController _upiTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _openCheckout();
  }

  /// Loads the bill. **Razorpay does not open here.**
  ///
  /// The patient lands on the summary — the doctor, the time, the fee
  /// breakdown — and Razorpay opens only when they tap "Pay ₹…". It used to
  /// open the moment this screen did, which put a payment sheet in front of
  /// somebody who had not yet seen what they were paying for, or for whom.
  Future<void> _openCheckout() async {
    await _controller.load(widget.args.doctor, widget.args.mode);
  }

  /// What the confirm button says while payments are paused.
  String get _confirmLabel => widget.args.scheduledAt != null
      ? tr('Confirm booking')
      : tr('Confirm & find doctor');

  @override
  void dispose() {
    _upiTextController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showError() {
    final message = _controller.errorMessage;
    if (message == null) return;

    AppSnackBar.error(context, message);
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (!await _controller.verifyUpi() && mounted) _showError();
  }

  Future<void> _pay() async {
    FocusScope.of(context).unfocus();

    final session = widget.args.anonymousSession;

    // The booking is filed here, inside the same call: paying and holding the
    // slot either both happen or neither does. A patient who has paid and holds
    // no appointment is worse off than one who was told the slot had gone.
    final succeeded = await _controller.pay(
      scheduledAt: widget.args.scheduledAt,
      concern: session?.concern,
      isAnonymous: session != null,
      alias: session?.displayName,
      scheduledFor: widget.args.scheduledFor,
    );
    if (!mounted) return;

    if (!succeeded) {
      // PAYMENTS PAUSED: nothing was charged, so the payment-failed screen —
      // all about refunds and retrying a payment — does not apply. What can
      // fail now is the booking itself (the slot was just taken), and that is
      // said where the patient is. To restore payments, delete the three
      // lines below.
      if (paymentsPaused) {
        _showError();
        return;
      }
      await _showOutcome();
      return;
    }

    final summary = _controller.summary!;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.paymentSuccess,
      arguments: PaymentSuccessArgs(
        doctor: summary.doctor,
        mode: summary.mode,
        formattedTotal: summary.fees.formattedTotal,
        // Empty while payments are paused: there is no transaction.
        transactionId: _controller.transactionId ?? '',
        // Carries the flow through: a booked slot confirms, an instant
        // consultation goes on to matching.
        scheduledFor: widget.args.scheduledFor,
        anonymousSession: session,
      ),
    );
  }

  /// Says what the failed attempt means, on a screen of its own, and does what
  /// the patient chooses there.
  ///
  /// It used to be a snackbar over this form, with the Pay button still live
  /// underneath — which read as "tap Pay again" whatever had happened,
  /// including when the payment had gone through and only the confirmation had
  /// not. That is the one case where paying again charges twice, and the
  /// outcome screen is the thing that refuses to offer it.
  ///
  /// Nothing here moves forward. Retry re-opens checkout on this same booking;
  /// every other answer leaves the booking flow.
  Future<void> _showOutcome() async {
    final reason = _controller.failureReason ?? PaymentFailureReason.declined;
    final summary = _controller.summary;

    final choice = await Navigator.of(context).pushNamed<PaymentFailureChoice>(
      AppRoutes.paymentFailed,
      arguments: PaymentFailedArgs(
        reason: reason,
        doctorName: summary?.doctor.name ?? widget.args.doctor.name,
        formattedTotal: summary?.fees.formattedTotal,
        detail: _controller.errorMessage,
        isScheduled: widget.args.scheduledAt != null,
      ),
    );

    if (!mounted) return;

    switch (choice) {
      case PaymentFailureChoice.retry:
        await _pay();
      case PaymentFailureChoice.back:
        // Back to the doctor or the time picker — where the patient was before
        // they tapped Pay. Not left on this form, which for a Razorpay build is
        // only ever a backdrop to a checkout that is now closed.
        Navigator.of(context).pop();
      case null:
        // The outcome screen went home itself, taking this route with it.
        break;
    }
  }

  void _payWithApp(UpiApp app) {
    // TODO(payment): hand off to the app's intent once the gateway is wired.
    AppSnackBar.info(
      context,
      tr('{document} is coming soon.', {'document': app.label}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        scrollable: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTopBar(
                  // PAYMENTS PAUSED: was 'Payment'.
                  title: paymentsPaused ? 'Confirm booking' : 'Payment',
                  variant: AppTopBarVariant.outlined,
                  centerTitle: true,
                ),
                Expanded(child: _Body(state: this)),
                _PayBar(state: this),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final _PaymentScreenState state;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final controller = state._controller;
    final summary = controller.summary;

    if (summary == null) {
      return controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: sizing.screenPadding,
                child: Text(
                  tr(controller.errorMessage ?? 'Payment is unavailable.'),
                  style: sizing.text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingMd,
        sizing.screenPaddingH,
        sizing.spacingXl,
      ),
      children: [
        PaymentDoctorCard(
          doctor: summary.doctor,
          mode: summary.mode,
          scheduledFor: state.widget.args.scheduledFor,
        ),
        SizedBox(height: sizing.spacingLg),
        // ===== PAYMENTS PAUSED ==============================================
        // No fee, no payment method: the booking is confirmed for free. To
        // restore payments, delete this `if` and its note, and the
        // `if (paymentsPaused) ...[] else` guard below.
        if (paymentsPaused) const _NoPaymentNote(),
        if (!paymentsPaused) ...[
          FeeBreakdownCard(fees: summary.fees),
          SizedBox(height: sizing.spacingLg),
        ],
        // ====================================================================
        // Razorpay asks for the method itself — UPI, card, netbanking, saved
        // cards and the UPI-app handoff are all inside its sheet. Asking here
        // as well would be the same question twice, and the answer given here
        // would be thrown away by the one that follows it.
        if (paymentsPaused)
          ...[]
        else if (controller.gatewayCollectsMethod) ...[
          _RazorpayHandoffNote(isTestMode: summary.isTestMode),
        ] else ...[
          Text(tr('Select Payment Method'), style: sizing.text.listTitle),
          SizedBox(height: sizing.spacingSm),
          for (final method in PaymentMethod.values) ...[
            if (method != PaymentMethod.values.first)
              SizedBox(height: sizing.spacingSm),
            PaymentMethodTile(
              method: method,
              isSelected: controller.method == method,
              onSelected: () => controller.changeMethod(method),
              details: method.needsUpiId
                  ? UpiDetails(
                      controller: state._upiTextController,
                      onChanged: controller.changeUpiId,
                      onVerify: state._verify,
                      canVerify: controller.canVerifyUpi,
                      isVerifying: controller.isVerifying,
                      verifiedAccountName: controller.verifiedAccountName,
                      onAppSelected: state._payWithApp,
                    )
                  : null,
            ),
          ],
        ],
      ],
    );
  }
}

/// The secured note and the pay button, pinned below the scrolling review.
class _PayBar extends StatelessWidget {
  const _PayBar({required this.state});

  final _PaymentScreenState state;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final controller = state._controller;

    return Container(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingSm,
        sizing.screenPaddingH,
        sizing.spacingMd,
      ),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PAYMENTS PAUSED: the "Secured by RazorPay" line is hidden — there
          // is no payment to secure. Delete the `if` to restore it.
          if (!paymentsPaused) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: sizing.iconXs * 0.9,
                  color: AppColors.success,
                ),
                SizedBox(width: sizing.spacingXxs * 1.5),
                Flexible(
                  child: Text(
                    tr('Secured by RazorPay • 256-bit encryption'),
                    style: sizing.text.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: sizing.spacingSm),
          ],
          AppButton.primary(
            // PAYMENTS PAUSED: was `controller.payLabel` ("Pay ₹…").
            label: paymentsPaused ? state._confirmLabel : controller.payLabel,
            isLoading: controller.isPaying,
            onPressed: controller.canPay ? state._pay : null,
          ),
        ],
      ),
    );
  }
}

/// PAYMENTS PAUSED: says plainly that nothing is charged, where the fee and
/// the payment method used to be.
class _NoPaymentNote extends StatelessWidget {
  const _NoPaymentNote();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: sizing.iconSm,
            color: AppColors.success,
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('No payment needed'), style: sizing.text.cardTitle),
                SizedBox(height: sizing.spacingXxs),
                Text(
                  tr(
                    'Confirm below and your consultation is booked straight '
                    'away.',
                  ),
                  style: sizing.text.cardBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Replaces the method list when Razorpay is collecting the payment.
///
/// Says where the patient is about to go. A sheet that opens on its own with no
/// warning reads as the app doing something unasked — naming it first makes it
/// the expected next step instead.
class _RazorpayHandoffNote extends StatelessWidget {
  const _RazorpayHandoffNote({required this.isTestMode});

  /// From the server, which holds the key — see `PaymentSummary.isTestMode`.
  final bool isTestMode;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(
          width: sizing.hairline,
          color: AppColors.consultAccent.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_rounded,
            size: sizing.iconSm,
            color: AppColors.primaryDeep,
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Paying securely with Razorpay'),
                  style: sizing.text.cardTitle.copyWith(
                    color: AppColors.primaryDeep,
                  ),
                ),
                SizedBox(height: sizing.spacingXxs),
                Text(
                  isTestMode
                      // Nobody should believe a test key moved money.
                      ? tr(
                          'Test mode — no money will be charged. Tap Pay to '
                          'choose UPI, card or netbanking.',
                        )
                      : tr('Tap Pay to choose UPI, card or netbanking.'),
                  style: sizing.text.cardBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
