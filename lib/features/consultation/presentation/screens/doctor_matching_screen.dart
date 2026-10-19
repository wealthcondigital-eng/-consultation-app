import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../anonymous/domain/entities/anonymous_session.dart';
import '../../../call/presentation/screens/call_screen.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/presentation/screens/doctor_list_screen.dart';
import '../../domain/entities/consultation_mode.dart';
import '../controllers/doctor_matching_controller.dart';
import '../controllers/doctor_search_session.dart';
import '../widgets/matching_progress_ring.dart';
import '../widgets/matching_steps.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../payment/domain/entities/payment_failure.dart';
import '../../../payment/presentation/screens/payment_failed_screen.dart';

/// What the patient asked for, so matching knows what to look for.
class DoctorMatchingArgs {
  const DoctorMatchingArgs({
    required this.mode,
    this.doctor,
    this.listing,
    this.anonymous,
    this.concern,
    this.paidTotal,
  });

  /// `₹750`, when this request was paid for before it was filed.
  ///
  /// What turns "nobody answered" from a shrug into a refund notice. A search
  /// that runs out on a *paid* request is money the patient needs to hear
  /// about, and the screen that says so names the amount — "₹750 is being
  /// refunded" is a sentence a person can check against a statement. Null on
  /// discovery, which files nothing and costs nothing.
  final String? paidTotal;

  bool get isPaid => paidTotal != null;

  final ConsultationMode mode;

  /// The doctor already chosen, when the patient booked a specific one. Null
  /// when anyone available will do.
  final Doctor? doctor;

  /// Set when the search is on behalf of a listing: matching hands these
  /// arguments over once it finishes, and the patient picks from the result.
  /// Null when the doctor is already paid for and the consultation is next.
  final DoctorListArgs? listing;

  /// Set when the patient is consulting under an alias.
  ///
  /// It travels on the consultation request, and the alias is the only name the
  /// doctor is sent. There is no separate anonymous flow — that was the bug:
  /// the old one ended at a stub that opened a local "session" and rang nobody.
  final AnonymousSession? anonymous;

  /// What the patient wrote about why they are consulting. Reaches the doctor
  /// on the request itself, which is what lets them read it before answering.
  ///
  /// Falls back to the anonymous booking's own concern, so the two cannot
  /// disagree about which one travels.
  final String? concern;

  String? get concernText => concern ?? anonymous?.concern;
}

/// The waiting screen while a doctor is found and connected.
///
/// Two very different searches wear this screen, and the difference is what
/// leaving it does.
///
/// **Discovery** — on the way to a listing — files nothing and rings nobody, so
/// backing out leaves it running in `DoctorSearchSession` and the dashboard
/// reports it. That is the fix for a search thrown away by a back gesture.
///
/// **A request** — a doctor is already chosen — is a doctor's phone ringing, so
/// leaving withdraws it. A request left running in the background is somebody
/// being rung for a call nobody is waiting on.
class DoctorMatchingScreen extends StatefulWidget {
  const DoctorMatchingScreen({super.key, required this.args});

  final DoctorMatchingArgs args;

  @override
  State<DoctorMatchingScreen> createState() => _DoctorMatchingScreenState();
}

class _DoctorMatchingScreenState extends State<DoctorMatchingScreen> {
  late final DoctorMatchingController _controller =
      sl<DoctorMatchingController>();

  /// The app-wide search. Only used in discovery mode, and deliberately not
  /// disposed here — it belongs to the app, not to this screen.
  late final DoctorSearchSession _session = sl<DoctorSearchSession>();

  bool _handledMatch = false;

  bool get _isDiscovery => widget.args.listing != null;

  @override
  void initState() {
    super.initState();

    if (widget.args.listing case final listing?) {
      _session.addListener(_onSearchChanged);
      // Started on the session rather than here, so it survives this screen.
      // Nothing is filed and nobody is rung, which is what makes leaving it
      // running safe.
      _session.start(
        speciality: listing.speciality,
        instantOnly: listing.instantOnly,
      );
      return;
    }

    _controller.addListener(_onChanged);
    _controller.start(
      widget.args.mode,
      doctorId: widget.args.doctor?.id,
      // Null unless the patient is consulting under an alias, which is what
      // makes this an anonymous consultation on the API rather than a separate
      // flow in the app.
      alias: widget.args.anonymous?.displayName,
      concern: widget.args.concernText,
    );
  }

  @override
  void dispose() {
    if (_isDiscovery) {
      _session.removeListener(_onSearchChanged);
    } else {
      _controller
        ..removeListener(_onChanged)
        ..dispose();
    }
    super.dispose();
  }

  /// The discovery search finished. Hand the patient the doctors who can
  /// actually take a call now, and let them choose — which is where the call
  /// type is asked for too.
  void _onSearchChanged() {
    if (!mounted || _handledMatch || _session.isSearching) return;

    if (_session.phase == DoctorSearchPhase.idle) {
      // Cleared from under us — the dashboard card was dismissed while this
      // screen was still open. Nothing left to show.
      _handledMatch = true;
      Navigator.of(context).pop();
      return;
    }

    if (!_session.hasResults) {
      // Nobody online, or the search failed. Said once, here, and the session
      // is cleared so the dashboard does not repeat it as a card.
      _handledMatch = true;
      final message = _session.errorMessage ?? _session.detail;
      _session.clear();
      AppSnackBar.info(context, message);
      Navigator.of(context).pop();
      return;
    }

    _handledMatch = true;
    final listing = widget.args.listing!;

    // Seen, so the dashboard has nothing left to offer. Clearing here rather
    // than on the listing screen keeps the card's lifetime simple: it exists
    // from the moment a search starts until the patient has looked at it.
    _session.clear();

    Navigator.of(
      context,
    ).pushReplacementNamed(AppRoutes.doctorList, arguments: listing);
  }

  void _onChanged() {
    if (!mounted) return;

    // The search ended with nobody: the queue timed out, or the request was
    // withdrawn. Says so and steps back, rather than spinning on a ring that
    // is never going to be answered.
    if (_controller.endedReason case final reason? when !_handledMatch) {
      _handledMatch = true;

      // Paid for, so this is a refund and it gets a screen that says so. A
      // snackbar reading "no doctor answered" over a patient who had just paid
      // was the worst message in the app: it said the consultation was off
      // and nothing at all about their money.
      if (widget.args.isPaid) {
        _showUnfulfilled(PaymentFailureReason.noDoctor);
        return;
      }

      AppSnackBar.info(context, reason);
      Navigator.of(context).popUntil(ModalRoute.withName(AppRoutes.home));
      return;
    }

    // The request could not be filed at all — the network dropped, or the
    // doctor went offline between the payment and the request. On a paid one
    // that is the same news as nobody answering, and it used to leave the
    // patient on a spinner with an error line and a Cancel button, having paid.
    if (_controller.errorMessage != null &&
        widget.args.isPaid &&
        !_handledMatch) {
      _handledMatch = true;
      _showUnfulfilled(PaymentFailureReason.noDoctor);
      return;
    }

    if (!_controller.isMatched || _handledMatch) return;

    // Fires once: the controller notifies again as the screen settles.
    _handledMatch = true;

    // A brokered consultation — a doctor accepted, and both sides now hold the
    // same channel. Straight into the call: the patient has already waited, and
    // the doctor is on the other end right now.
    if (_controller.matchedConsultation case final consultation?) {
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.call,
        arguments: CallArgs.fromConsultation(consultation),
      );
      return;
    }

    // No consultation behind the match. Only the stub backend does this, and
    // there is no room to open — so the patient is returned to the dashboard
    // rather than dropped into a call screen with no channel.
    AppSnackBar.info(context, 'That consultation could not be opened.');
    Navigator.of(context).popUntil(ModalRoute.withName(AppRoutes.home));
  }

  /// Leaves the search running and steps back to the dashboard, where the card
  /// carries on reporting it.
  ///
  /// Discovery only. There is nothing to withdraw — no request was filed — so
  /// this really is only a change of screen.
  void _minimise() {
    Navigator.of(context).popUntil(ModalRoute.withName(AppRoutes.home));
  }

  Future<void> _cancel() async {
    if (_isDiscovery) {
      // Explicitly given up on, so the search goes too. Backing out is the
      // other gesture, and it keeps it.
      _session.clear();
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    final wasPaidAndWaiting = widget.args.isPaid && !_controller.isMatched;

    _controller.cancel();
    if (!mounted) return;

    // Called off after paying, before any doctor answered. Refunded on the
    // server, and said here — leaving someone who has just paid on the home
    // screen with no word about the money is how support tickets start.
    if (wasPaidAndWaiting) {
      _handledMatch = true;
      _showUnfulfilled(PaymentFailureReason.withdrawn);
      return;
    }

    // Back to where the patient started rather than into the payment screens.
    Navigator.of(context).popUntil(ModalRoute.withName(AppRoutes.home));
  }

  /// A paid request that ended without a consultation.
  ///
  /// Replaces this screen rather than stacking on it: the search is over, and
  /// the outcome screen's only way out is home.
  void _showUnfulfilled(PaymentFailureReason reason) {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.paymentFailed,
      arguments: PaymentFailedArgs(
        reason: reason,
        doctorName: widget.args.doctor?.name ?? tr('The doctor'),
        formattedTotal: widget.args.paidTotal,
      ),
    );
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
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;

          // The system gesture means different things on the two searches. On
          // discovery it backgrounds the search — nobody is being rung, and the
          // dashboard picks it up. On a request it is a withdrawal, because
          // leaving a doctor ringing for a patient who has gone is the one
          // thing this must not do.
          if (_isDiscovery) {
            _minimise();
          } else {
            _cancel();
          }
        },
        child: ResponsivePage(
          // The body scrolls itself so the actions stay reachable on a short
          // screen without relying on intrinsic heights.
          scrollable: false,
          child: ListenableBuilder(
            listenable: _isDiscovery ? _session : _controller,
            builder: (context, _) {
              final update = _isDiscovery
                  ? _session.update
                  : _controller.update;
              final isMatched = _isDiscovery
                  ? _session.hasResults
                  : _controller.isMatched;

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        sizing.screenPaddingH,
                        sizing.spacingXxxl,
                        sizing.screenPaddingH,
                        sizing.spacingXl,
                      ),
                      child: Column(
                        children: [
                          MatchingProgressRing(isSpinning: !isMatched),
                          SizedBox(height: sizing.spacingXxxl),
                          _Headline(
                            title: _headlineTitle,
                            detail: _headlineDetail,
                            waitLabel: _waitLabel,
                            isError: _errorMessage != null,
                          ),
                          SizedBox(height: sizing.spacingXxxl),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: sizing.w(280),
                            ),
                            child: MatchingSteps(
                              update: update,
                              doctorName: _chosenDoctor?.name,
                            ),
                          ),
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
                        // Offered only while a discovery search is running.
                        // There is nothing to background on a request — the
                        // doctor's phone is ringing — and nothing left to
                        // background once the answer is in.
                        if (_isDiscovery && _session.isSearching) ...[
                          AppButton.primary(
                            label: 'Search in the background',
                            onPressed: _minimise,
                          ),
                          SizedBox(height: sizing.spacingXs),
                          Text(
                            tr(
                              'We will keep looking and tell you on your '
                              'dashboard.',
                            ),
                            style: sizing.text.caption,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: sizing.spacingSm),
                        ],
                        AppButton.secondary(
                          label: isMatched ? 'Close' : 'Cancel',
                          onPressed: _cancel,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String? get _errorMessage =>
      _isDiscovery ? _session.errorMessage : _controller.errorMessage;

  /// The doctor the patient chose and paid for, when there is one. Then this
  /// screen is not *finding* anybody — the patient already did — it is
  /// ringing that doctor, and it says so.
  Doctor? get _chosenDoctor => _isDiscovery ? null : widget.args.doctor;

  String get _headlineTitle {
    if (_errorMessage != null) return tr('We could not connect you');
    if (_isDiscovery) return _session.headline;
    final chosen = _chosenDoctor;
    if (_controller.isMatched) {
      return chosen == null ? tr('Doctor found') : tr('Doctor answered');
    }
    if (chosen != null) {
      return tr('Connecting you with {name}…', {'name': chosen.name});
    }
    return tr('Finding you the best doctor...');
  }

  String get _headlineDetail {
    if (_errorMessage case final message?) return tr(message);
    if (_isDiscovery) return _session.detail;
    if (_controller.isMatched) {
      return tr('{name} is joining now', {
        'name': _controller.matchedDoctor?.name ?? tr('Your doctor'),
      });
    }
    if (_chosenDoctor != null) {
      return tr('Please wait while your doctor answers the call');
    }
    return tr('Please wait while we connect you to an available doctor');
  }

  /// Null once there is nothing left to wait for, which is what takes the
  /// countdown off a finished search.
  String? get _waitLabel {
    if (_errorMessage != null) return null;

    if (_isDiscovery) {
      return _session.isSearching
          ? tr('Estimated time {time}', {'time': _session.remainingLabel})
          : null;
    }

    return _controller.isMatched
        ? null
        : tr('Estimated time {time}', {'time': _controller.remainingLabel});
  }
}

/// The three lines above the steps: what is happening, what that means, and how
/// long it is expected to take.
class _Headline extends StatelessWidget {
  const _Headline({
    required this.title,
    required this.detail,
    required this.waitLabel,
    required this.isError,
  });

  final String title;
  final String detail;

  /// Null once there is nothing to count down.
  final String? waitLabel;

  final bool isError;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      children: [
        Text(
          title,
          style: sizing.text.screenTitleCompact,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: sizing.spacingSm),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: sizing.w(320)),
          child: Text(
            detail,
            style: sizing.text.helperText,
            textAlign: TextAlign.center,
          ),
        ),
        if (!isError && waitLabel != null) ...[
          SizedBox(height: sizing.spacingSm),
          Text(
            waitLabel!,
            style: sizing.text.screenSubtitle.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
