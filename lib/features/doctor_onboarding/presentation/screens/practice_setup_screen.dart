import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/practice_setup.dart';
import '../controllers/practice_setup_controller.dart';
import '../widgets/consultation_fee_field.dart';
import 'set_availability_screen.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/l10n/tr.dart';

/// The setup wizard's first stop: what a consultation costs.
///
/// **Two prices, entered separately.** It used to collect one amount and write
/// it to both the video and the audio fee, so a doctor could not charge less
/// for a voice call — which is what almost all of them want to do. It also
/// offered four fixed chips and nothing else, so ₹450 was unsayable.
///
/// Reached twice: as a step of the post-approval wizard, and from the doctor's
/// profile afterwards. [isWizardStep] is what tells the two apart, because
/// where Continue goes depends on it and guessing from the navigator stack got
/// it wrong.
class PracticeSetupScreen extends StatefulWidget {
  const PracticeSetupScreen({super.key, this.isWizardStep = false});

  /// True when this is a step of onboarding, so saving moves on to Set
  /// Availability. False when the doctor opened it from their profile, where
  /// saving means going back.
  final bool isWizardStep;

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  late final PracticeSetupController _controller =
      sl<PracticeSetupController>();

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onChanged)
      ..load();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  /// Surfaces every failure, including one from the *load*.
  ///
  /// The load's message used to be recorded and never shown: only `_continue`
  /// read `errorMessage`, so a failed read left a screen that looked fine and
  /// would not save, with nothing said about why.
  void _onChanged() {
    final message = _controller.errorMessage;
    if (message == null || !mounted) return;

    _controller.acknowledgeError();
    AppSnackBar.error(context, message);
  }

  Future<void> _continue() async {
    final saved = await _controller.save();
    if (!saved || !mounted) return;

    // Where "done" goes depends on why the doctor is here, and the screen is
    // told rather than left to guess. `canPop` still answers whether popping
    // is *possible*: opened as the app's first route there is nothing behind
    // this, and a pop would close the app rather than go anywhere.
    if (!widget.isWizardStep && Navigator.of(context).canPop()) {
      AppSnackBar.success(context, 'Consultation fees saved.');
      Navigator.of(context).pop(_controller.setup);
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRoutes.doctorAvailability,
      arguments: const SetAvailabilityArgs(isWizardStep: true),
    );
  }

  /// Onboarding only. A doctor who opened this from their profile came to
  /// change a price, and "skip" there would just be a second Back.
  void _skip() {
    Navigator.of(context).pushNamed(
      AppRoutes.doctorAvailability,
      arguments: const SetAvailabilityArgs(isWizardStep: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

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
          builder: (context, _) {
            if (_controller.isInitialLoad) {
              return const Center(child: CircularProgressIndicator());
            }

            final setup = _controller.setup;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTopBar(
                  title: widget.isWizardStep
                      ? 'Setup Wizard'
                      : 'Consultation Fee',
                  variant: AppTopBarVariant.outlined,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      sizing.screenPaddingH,
                      sizing.spacingXs,
                      sizing.screenPaddingH,
                      sizing.spacingXl,
                    ),
                    children: [
                      if (widget.isWizardStep) ...[
                        _Progress(setup: setup),
                        SizedBox(height: sizing.spacingXl),
                      ],
                      Text(
                        tr('Consultation Fees'),
                        style: sizing.text.cardTitleLarge,
                      ),
                      SizedBox(height: sizing.spacingXxs),
                      Text(
                        tr(
                          'Price each consultation type. A patient sees the fee '
                          'before they book, and it is fixed for a call once '
                          'they do.',
                        ),
                        style: sizing.text.helperText,
                      ),
                      SizedBox(height: sizing.spacingLg),
                      ConsultationFeeField(
                        kind: ConsultationFeeKind.video,
                        setup: setup,
                        errorText: _controller.showErrors
                            ? ConsultationFeeKind.video.errorFor(setup)
                            : null,
                        onChanged: (fee) =>
                            _controller.setFee(ConsultationFeeKind.video, fee),
                      ),
                      SizedBox(height: sizing.spacingMd),
                      ConsultationFeeField(
                        kind: ConsultationFeeKind.audio,
                        setup: setup,
                        errorText: _controller.showErrors
                            ? ConsultationFeeKind.audio.errorFor(setup)
                            : null,
                        onChanged: (fee) =>
                            _controller.setFee(ConsultationFeeKind.audio, fee),
                        // One tap instead of re-typing a number they have just
                        // entered. Hidden when it would do nothing.
                        trailing:
                            setup.videoFee == null ||
                                setup.audioFee == setup.videoFee
                            ? null
                            : _MatchVideoButton(
                                onTap: _controller.matchAudioToVideo,
                              ),
                      ),
                      SizedBox(height: sizing.spacingLg),
                      _Summary(setup: setup),
                      SizedBox(height: sizing.spacingXl),
                      AppButton.primary(
                        label: widget.isWizardStep ? 'Continue' : 'Save fees',
                        isLoading: _controller.isSaving,
                        onPressed: _controller.canSave ? _continue : null,
                      ),
                      if (widget.isWizardStep) ...[
                        SizedBox(height: sizing.spacingXs),
                        Center(
                          child: TextButton(
                            onPressed: _controller.isSaving ? null : _skip,
                            child: Text(
                              tr('Skip for now'),
                              style: sizing.text.countdownLabel,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// `Setup Progress` and the bar under it.
class _Progress extends StatelessWidget {
  const _Progress({required this.setup});

  final PracticeSetup setup;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(tr('Setup Progress'), style: sizing.text.fieldLabel),
            ),
            Text(
              tr('{percent}% Completed', {'percent': setup.percentComplete}),
              style: sizing.text.fieldLabel.copyWith(
                color: AppColors.primaryVivid,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: sizing.spacingXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(sizing.radiusPill),
          child: LinearProgressIndicator(
            value: setup.progress,
            minHeight: sizing.h(6),
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(AppColors.primaryDeep),
          ),
        ),
      ],
    );
  }
}

/// What is about to be saved, in one line.
///
/// The old screen showed the single fee in a large tinted card. With two fees
/// that card would be two cards saying what the fields above already say, so
/// this restates them together — which is the thing worth checking, since one
/// being blank is a legal state that stops that consultation type being
/// offered.
class _Summary extends StatelessWidget {
  const _Summary({required this.setup});

  final PracticeSetup setup;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final unpriced = [
      if (setup.videoFee == null) 'video',
      if (setup.audioFee == null) 'audio',
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(
          width: sizing.hairline,
          color: AppColors.consultAccent.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payments_rounded,
                size: sizing.iconSm,
                color: AppColors.primaryVivid,
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Text(
                  feeSummaryText(setup),
                  style: sizing.text.cardTitle.copyWith(
                    color: AppColors.primaryVivid,
                  ),
                ),
              ),
            ],
          ),
          if (unpriced.isNotEmpty) ...[
            SizedBox(height: sizing.spacingXs),
            Text(
              // Named rather than warned about: leaving one blank is allowed,
              // and a doctor who only wants to do video should be told what
              // that means rather than stopped.
              tr(
                'Leaving the ${unpriced.join(' and ')} fee blank means you '
                'will not be offered ${unpriced.join(' or ')} consultations.',
              ),
              style: sizing.text.legalBody,
            ),
          ],
        ],
      ),
    );
  }
}

/// [PracticeSetup.selectedFeeLabel], in the active language.
String feeSummaryText(PracticeSetup setup) {
  final video = setup.videoFee;
  final audio = setup.audioFee;
  if (video == null && audio == null) return '—';
  if (video == audio) return setup.formatFee(video!);
  if (audio == null) {
    return tr('{fee} video', {'fee': setup.formatFee(video!)});
  }
  if (video == null) return tr('{fee} audio', {'fee': setup.formatFee(audio)});

  return tr('{video} video · {audio} audio', {
    'video': setup.formatFee(video),
    'audio': setup.formatFee(audio),
  });
}

class _MatchVideoButton extends StatelessWidget {
  const _MatchVideoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: sizing.spacingXs),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(tr('Same as video'), style: sizing.text.sectionAction),
    );
  }
}
