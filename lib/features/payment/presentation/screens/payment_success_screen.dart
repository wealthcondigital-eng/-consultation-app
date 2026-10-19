import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../anonymous/domain/entities/anonymous_session.dart';
import '../../../consultation/presentation/screens/doctor_matching_screen.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../controllers/payment_controller.dart' show paymentsPaused;

/// What was paid for, carried into the confirmation.
class PaymentSuccessArgs {
  const PaymentSuccessArgs({
    required this.doctor,
    required this.mode,
    required this.formattedTotal,
    required this.transactionId,
    this.scheduledFor,
    this.anonymousSession,
  });

  final Doctor doctor;
  final ConsultationMode mode;
  final String formattedTotal;
  final String transactionId;

  /// The booked day and time, e.g. `Mon, 18 Aug at 10:30 AM`. Null for a
  /// consultation that starts as soon as it is paid for.
  final String? scheduledFor;

  /// Set when the patient is consulting under an alias.
  ///
  /// Carried through payment rather than dropped at it, which is what used to
  /// happen: an anonymous patient paid, this screen handed over to matching
  /// with no session, and the request was filed under their real name. The
  /// alias is the only thing the doctor was ever supposed to see.
  final AnonymousSession? anonymousSession;
}

/// Confirms the charge.
///
/// A booked appointment ends here: the slot is already held, so there is no
/// doctor to match. An instant consultation hands off to matching instead.
///
/// This screen has no Figma design yet — it is built from the existing tokens
/// and should be replaced when one lands.
class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key, required this.args});

  final PaymentSuccessArgs args;

  /// How long the confirmation stays up before matching starts on its own.
  static const Duration autoAdvanceAfter = Duration(seconds: 2);

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  Timer? _autoAdvance;

  /// A slot was booked, so this is a confirmation and not a waiting room.
  bool get _isScheduled => widget.args.scheduledFor != null;

  @override
  void initState() {
    super.initState();
    // An instant patient is waiting on a doctor, so that flow does not need a
    // tap to move on — the button is there for anyone who does not want to
    // wait. A booked appointment has nowhere to advance to.
    if (!_isScheduled) {
      _autoAdvance = Timer(PaymentSuccessScreen.autoAdvanceAfter, _continue);
    }
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    super.dispose();
  }

  void _continue() {
    _autoAdvance?.cancel();
    if (!mounted) return;

    // Replaces the payment screens: paying again by going back is not a thing.
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.doctorMatching,
      ModalRoute.withName(AppRoutes.home),
      arguments: DoctorMatchingArgs(
        doctor: widget.args.doctor,
        mode: widget.args.mode,
        // The alias and the concern the patient wrote, both of which reach the
        // doctor on the request itself — the concern is the only thing they
        // know about an anonymous caller when deciding whether to answer.
        anonymous: widget.args.anonymousSession,
        // Paid, so a search that runs out is a refund and the matching screen
        // says so, naming the amount.
        // PAYMENTS PAUSED: nothing was paid, so there is nothing to refund.
        paidTotal: paymentsPaused ? null : widget.args.formattedTotal,
      ),
    );
  }

  /// Ends the booking flow: back to home, skipping the paid-for payment form.
  /// Falls back to the first route if home is somehow not on the stack.
  void _done() {
    Navigator.of(context).popUntil(
      (route) => route.settings.name == AppRoutes.home || route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final args = widget.args;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: PopScope(
        // Going back would land on the payment form for a paid consultation.
        canPop: false,
        // A booked appointment is a dead end, so treat back as "done" rather
        // than trapping the patient on the confirmation.
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isScheduled) _done();
        },
        child: ResponsivePage(
          scrollable: false,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: sizing.screenPadding,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: sizing.r(96),
                        height: sizing.r(96),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.successSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: sizing.r(48),
                          color: AppColors.success,
                        ),
                      ),
                      SizedBox(height: sizing.spacingXl),
                      Text(
                        _isScheduled
                            ? tr('Appointment scheduled')
                            // PAYMENTS PAUSED: was 'Payment successful'.
                            : paymentsPaused
                            ? tr('Consultation confirmed')
                            : tr('Payment successful'),
                        style: sizing.text.screenTitleCompact,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: sizing.spacingXs),
                      Text(
                        _isScheduled
                            ? tr(
                                'Your {mode} consultation with {doctor} is '
                                'confirmed for {when}.',
                                {
                                  'mode': tr(
                                    args.mode.shortLabel,
                                  ).toLowerCase(),
                                  'doctor': args.doctor.name,
                                  'when': args.scheduledFor,
                                },
                              )
                            // PAYMENTS PAUSED: no amount to name.
                            : paymentsPaused
                            ? tr(
                                'Your {mode} consultation with {doctor} is '
                                'confirmed. Connecting you now.',
                                {
                                  'mode': tr(
                                    args.mode.shortLabel,
                                  ).toLowerCase(),
                                  'doctor': args.doctor.name,
                                },
                              )
                            : tr(
                                '{amount} paid for a {mode} consultation '
                                'with {doctor}.',
                                {
                                  'amount': args.formattedTotal,
                                  'mode': tr(
                                    args.mode.shortLabel,
                                  ).toLowerCase(),
                                  'doctor': args.doctor.name,
                                },
                              ),
                        style: sizing.text.helperText,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: sizing.spacingMd),
                      // PAYMENTS PAUSED: no amount paid and no payment
                      // reference to show. Delete the `if` to restore it.
                      if (!paymentsPaused)
                        Text(
                          _isScheduled
                              ? tr('{amount} paid · Reference {reference}', {
                                  'amount': args.formattedTotal,
                                  'reference': args.transactionId,
                                })
                              : tr('Reference {reference}', {
                                  'reference': args.transactionId,
                                }),
                          style: sizing.text.caption,
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: sizing.screenPadding,
                child: AppButton.primary(
                  // The patient chose the doctor already; this connects to them.
                  label: _isScheduled ? 'Done' : 'Connect to doctor',
                  onPressed: _isScheduled ? _done : _continue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
