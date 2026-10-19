import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/consultation_mode.dart';
import '../controllers/consultation_feedback_controller.dart';

/// The consultation being reviewed.
class ConsultationFeedbackArgs {
  const ConsultationFeedbackArgs({
    required this.consultationId,
    required this.doctor,
    required this.mode,
    this.durationInSeconds = 0,
  });

  /// The record the review is written onto.
  ///
  /// Required, and that is the change: the screen used to be opened with a
  /// doctor and nothing else — from the *matching* screen, the moment a doctor
  /// was found and before a word had been said — so there was no consultation
  /// for a rating to belong to and Submit wrote nothing anywhere.
  final String consultationId;

  final Doctor doctor;
  final ConsultationMode mode;

  /// How long the call actually ran, per the server's clock.
  final int durationInSeconds;

  /// `12 min` / `48 sec`
  String get durationLabel {
    if (durationInSeconds <= 0) return '—';
    if (durationInSeconds < 60) {
      return tr('{seconds} sec', {'seconds': durationInSeconds});
    }

    final minutes = durationInSeconds ~/ 60;
    if (minutes < 60) return tr('{minutes} min', {'minutes': minutes});

    final hours = minutes ~/ 60;
    return tr('{hours} h {minutes} min', {
      'hours': hours,
      'minutes': (minutes % 60).toString().padLeft(2, '0'),
    });
  }
}

/// The review a patient leaves once a consultation has finished.
///
/// Reached from the call screen when it ends, on the patient's side only — the
/// one moment somebody is willing to answer, because they are still holding the
/// phone. What they write here is what appears on the doctor's profile.
class ConsultationFeedbackScreen extends StatefulWidget {
  const ConsultationFeedbackScreen({super.key, required this.args});

  final ConsultationFeedbackArgs args;

  @override
  State<ConsultationFeedbackScreen> createState() =>
      _ConsultationFeedbackScreenState();
}

class _ConsultationFeedbackScreenState
    extends State<ConsultationFeedbackScreen> {
  late final ConsultationFeedbackController _controller =
      sl<ConsultationFeedbackController>();

  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final stored = await _controller.submit(widget.args.consultationId);
    if (!mounted) return;

    if (!stored) {
      // Kept on the screen with what they wrote intact. Sending them home on a
      // failed write would lose the review with nothing said, and this is the
      // only moment they will ever be willing to write it.
      AppSnackBar.error(
        context,
        _controller.errorMessage ?? 'Your review could not be sent.',
      );
      return;
    }

    AppSnackBar.success(context, 'Thanks — your review is on their profile.');
    _leave();
  }

  /// Home, clearing the call and everything that led to it.
  void _leave() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final args = widget.args;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.canvas,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: PopScope(
        canPop: false,
        // Skipping is allowed, and back is how it is done. A review nobody can
        // decline to leave is a review nobody trusts.
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: ResponsivePage(
          backgroundColor: AppColors.canvas,
          scrollable: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Column(
                children: [
                  AppTopBar(
                    title: 'Rate Your Experience',
                    variant: AppTopBarVariant.outlined,
                    centerTitle: true,
                    onBack: _leave,
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
                        _ConsultationSummary(args: args),
                        SizedBox(height: sizing.spacingXl),
                        _RatingSection(
                          title: 'Rate the Doctor',
                          value: _controller.doctorRating,
                          iconSize: sizing.r(32),
                          onChanged: _controller.rateDoctor,
                        ),
                        SizedBox(height: sizing.spacingXl),
                        _RatingSection(
                          title: 'Call Quality',
                          // Said out loud, because otherwise a patient whose
                          // line kept breaking takes it out on the doctor's
                          // stars — and the doctor is charged for our network.
                          subtitle: 'The connection, not the doctor.',
                          value: _controller.callQuality,
                          iconSize: sizing.r(24),
                          onChanged: _controller.rateCallQuality,
                        ),
                        SizedBox(height: sizing.spacingXl),
                        Text(
                          tr('How was your experience?'),
                          style: sizing.text.cardTitle,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: sizing.spacingSm),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: sizing.spacingXs,
                          runSpacing: sizing.spacingXs,
                          children: [
                            for (final option
                                in ConsultationFeedbackController.experiences)
                              _ExperienceChip(
                                label: option,
                                isSelected: _controller.isSelected(option),
                                onTap: () =>
                                    _controller.toggleExperience(option),
                              ),
                          ],
                        ),
                        SizedBox(height: sizing.spacingXl),
                        TextField(
                          controller: _noteController,
                          minLines: 4,
                          maxLines: 4,
                          maxLength: 1000,
                          textInputAction: TextInputAction.newline,
                          onChanged: _controller.changeNote,
                          decoration: InputDecoration(
                            hintText: tr(
                              'Write a review for other patients '
                              '(optional)...',
                            ),
                            hintStyle: sizing.text.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                sizing.radiusLg,
                              ),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                sizing.radiusLg,
                              ),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        // Worth stating before they write rather than after:
                        // what goes in the box is published on the doctor's
                        // profile, and the name attached is not theirs.
                        Text(
                          tr(
                            'Your review appears on the doctor’s profile as '
                            '“Verified patient”. Your name is never shown.',
                          ),
                          style: sizing.text.caption,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      sizing.screenPaddingH,
                      sizing.spacingSm,
                      sizing.screenPaddingH,
                      sizing.spacingSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppButton.primary(
                          label: _controller.isSubmitting
                              ? 'Sending…'
                              : 'Submit Feedback',
                          // Disabled until there are stars. The rating is the
                          // thing being asked for; everything else on the
                          // screen is optional.
                          onPressed: _controller.canSubmit ? _submit : null,
                        ),
                        SizedBox(height: sizing.spacingXs),
                        TextButton(
                          onPressed: _controller.isSubmitting ? null : _leave,
                          child: Text(
                            tr('Skip'),
                            style: sizing.text.sectionAction,
                          ),
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
}

class _ExperienceChip extends StatelessWidget {
  const _ExperienceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return FilterChip(
      label: Text(tr(label)),
      selected: isSelected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: sizing.text.metaLabel.copyWith(
        color: isSelected ? AppColors.surface : AppColors.textLabel,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.surfaceMuted,
      selectedColor: AppColors.primaryVivid,
      side: BorderSide(
        color: isSelected ? AppColors.primaryVivid : AppColors.border,
      ),
      shape: const StadiumBorder(),
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingXs,
        vertical: sizing.spacingXxs,
      ),
    );
  }
}

class _ConsultationSummary extends StatelessWidget {
  const _ConsultationSummary({required this.args});

  final ConsultationFeedbackArgs args;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusXl),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: sizing.avatarSize,
                height: sizing.avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.avatarSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(width: sizing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(args.doctor.name, style: sizing.text.listTitle),
                    Text(
                      tr(args.doctor.speciality),
                      style: sizing.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: sizing.spacingMd),
            child: Divider(height: 1, color: AppColors.dividerFaint),
          ),
          Row(
            children: [
              _SummaryDetail(label: tr('TYPE'), value: tr(args.mode.label)),
              const Spacer(),
              _SummaryDetail(label: tr('DURATION'), value: args.durationLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryDetail extends StatelessWidget {
  const _SummaryDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: sizing.text.fieldCaption),
        SizedBox(height: sizing.spacingXxs),
        Text(
          value,
          style: sizing.text.metaLabel.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection({
    required this.title,
    required this.value,
    required this.iconSize,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final int value;
  final double iconSize;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      children: [
        Text(tr(title), style: sizing.text.cardTitle),
        if (subtitle case final subtitle?) ...[
          SizedBox(height: sizing.spacingXxs),
          Text(
            tr(subtitle),
            style: sizing.text.caption,
            textAlign: TextAlign.center,
          ),
        ],
        SizedBox(height: sizing.spacingSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final rating = index + 1;

            return IconButton(
              tooltip: rating == 1
                  ? tr('{rating} star', {'rating': rating})
                  : tr('{rating} stars', {'rating': rating}),
              onPressed: () => onChanged(rating),
              iconSize: iconSize,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: iconSize + sizing.spacingXs,
                height: iconSize + sizing.spacingXs,
              ),
              icon: Icon(
                rating <= value
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: rating <= value
                    ? const Color(0xFFF59E0B)
                    : AppColors.textTertiary,
              ),
            );
          }),
        ),
      ],
    );
  }
}
