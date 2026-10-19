import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/consultation_mode.dart';
import '../../domain/entities/live_consultation.dart';

/// A patient calling, on the doctor's home screen.
///
/// A banner pinned above the content rather than a modal sheet, deliberately.
/// The ring lasts thirty seconds and then goes to another doctor, so it has to
/// appear and disappear on its own — and a dialog that dismisses itself while a
/// doctor is reaching for it is worse than one that was never there. This
/// leaves the screen usable and simply stops being shown.
class IncomingCallBanner extends StatelessWidget {
  const IncomingCallBanner({
    super.key,
    required this.consultation,
    required this.isBusy,
    required this.onAccept,
    required this.onDecline,
  });

  final LiveConsultation consultation;

  /// True while an answer is in flight, so neither button can be tapped twice.
  final bool isBusy;

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Material(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: sizing.screenPaddingH,
            vertical: sizing.spacingMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    consultation.mode == ConsultationMode.video
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    color: Colors.white,
                  ),
                  SizedBox(width: sizing.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          switch (consultation.mode) {
                            ConsultationMode.video => tr(
                              'Incoming video consultation',
                            ),
                            ConsultationMode.audio => tr(
                              'Incoming audio consultation',
                            ),
                          },
                          style: sizing.text.cardTitle.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          // An anonymous patient is named by their alias and
                          // nothing else — which is the whole promise of the
                          // anonymous flow, so it is stated rather than implied.
                          consultation.isAnonymous
                              ? tr('{name} · anonymous', {
                                  'name': consultation.patientName,
                                })
                              : consultation.patientName,
                          style: sizing.text.bodySmall.copyWith(
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: sizing.spacingSm),
                  _AnswerButton(
                    icon: Icons.call_end_rounded,
                    color: AppColors.danger,
                    tooltip: tr('Decline'),
                    onPressed: isBusy ? null : onDecline,
                  ),
                  SizedBox(width: sizing.spacingXs),
                  _AnswerButton(
                    icon: Icons.call_rounded,
                    color: AppColors.success,
                    tooltip: tr('Accept'),
                    onPressed: isBusy ? null : onAccept,
                  ),
                ],
              ),
              // What the patient typed before asking. The doctor reads it
              // while deciding whether to answer, which is the whole reason it
              // travels on the request rather than arriving in the call: on an
              // anonymous consultation this is the **only** thing they know
              // about the person ringing, and "accept or decline" with nothing
              // to go on is not a decision.
              if (consultation.concern case final concern?) ...[
                SizedBox(height: sizing.spacingSm),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: sizing.spacingSm,
                    vertical: sizing.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(sizing.radiusMd),
                  ),
                  child: Text(
                    concern,
                    style: sizing.text.bodySmall.copyWith(color: Colors.white),
                    // Three lines is what fits above a home screen without
                    // covering it. The whole of it is on the consultation, and
                    // the call screen has room for the rest.
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.4),
      ),
    );
  }
}
