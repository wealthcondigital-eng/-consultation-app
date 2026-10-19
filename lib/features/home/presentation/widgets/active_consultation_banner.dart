import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../../core/l10n/tr.dart';

/// A consultation the patient is in the middle of, offered back to them.
///
/// The gap this closes: a patient who backgrounded the app during a call, or
/// whose phone rang, had **no way back into the room**. The consultation was
/// still open on the server, the doctor was still waiting, and the app's home
/// screen said nothing about it.
///
/// The second gap, and the reason this card now has two buttons: a request
/// still *searching* has no room to rejoin, so the card had nothing to offer at
/// all — it sat on the dashboard saying "Finding a doctor" with no way to stop.
/// Closing the app did not stop it either, because the request lives on the
/// server; the patient came back an hour later to the same card. Cancel
/// withdraws the request, which is what makes the card go away.
///
/// Above everything else on the screen, because it is more urgent than
/// whatever the patient was going to do next.
class ActiveConsultationBanner extends StatelessWidget {
  const ActiveConsultationBanner({
    super.key,
    required this.appointment,
    required this.onRejoin,
    required this.onCancel,
    this.isBusy = false,
    this.isCancelling = false,
  });

  final Appointment appointment;
  final VoidCallback onRejoin;

  /// Withdraws the request. Offered while the consultation has not started —
  /// once two people are in a room, leaving is hanging up, and that belongs on
  /// the call screen rather than here.
  final VoidCallback onCancel;

  /// True while the rejoin is being brokered, so a second tap cannot open two
  /// calls into the same room.
  final bool isBusy;

  /// True while the withdrawal is in flight.
  final bool isCancelling;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    // Three states, and they read differently. In the room is "go back";
    // ringing a doctor is "hold on"; still searching is "we are looking".
    final isInRoom = appointment.status == AppointmentStatus.inProgress;
    final isSearching = appointment.status == AppointmentStatus.searching;

    // Cancel is only meaningful before the call starts. Once it is under way
    // the patient hangs up, which is a different action in a different place.
    final canCancel =
        !isInRoom && appointment.status != AppointmentStatus.accepted;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: isInRoom ? AppColors.badgeSurface : AppColors.primarySurface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(
          width: sizing.hairline,
          color: isInRoom
              ? AppColors.successStrong
              : AppColors.consultAccent.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: sizing.iconChipSize * 0.75,
                height: sizing.iconChipSize * 0.75,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isInRoom ? AppColors.successStrong : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: isSearching
                    // A spinner rather than an hourglass while the queue is
                    // being worked: the card is reporting something that is
                    // happening, and a static glyph reads as stuck.
                    ? SizedBox.square(
                        dimension: sizing.iconSm,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Icon(
                        isInRoom
                            ? Icons.videocam_rounded
                            : Icons.ring_volume_rounded,
                        size: sizing.iconSm,
                        color: Colors.white,
                      ),
              ),
              SizedBox(width: sizing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isInRoom
                          ? tr('Consultation in progress')
                          : tr(appointment.status.label),
                      style: sizing.text.cardTitle.copyWith(
                        color: isInRoom
                            ? AppColors.success
                            : AppColors.primaryDeep,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sizing.spacingXxs / 2),
                    Text(
                      isSearching
                          // Naming the counterpart here would be naming nobody:
                          // on a searching request the row carries a
                          // placeholder, and "Finding a doctor / Finding a
                          // doctor" is what it used to render.
                          ? tr('We are looking for a doctor who is free now.')
                          : appointment.counterpartName,
                      style: sizing.text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (appointment.isRejoinable || canCancel) ...[
            SizedBox(height: sizing.spacingSm),
            Row(
              children: [
                if (canCancel)
                  Expanded(
                    child: _CancelButton(
                      isBusy: isCancelling,
                      onPressed: isBusy || isCancelling ? null : onCancel,
                    ),
                  ),
                // Only when there is actually a room to join. A request still
                // searching has no channel, and a button that cannot work is
                // worse than no button.
                if (appointment.isRejoinable) ...[
                  if (canCancel) SizedBox(width: sizing.spacingXs),
                  Expanded(
                    child: SizedBox(
                      height: sizing.buttonHeightCompact,
                      child: ElevatedButton(
                        onPressed: isBusy || isCancelling ? null : onRejoin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isInRoom
                              ? AppColors.successStrong
                              : AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              sizing.radiusMd,
                            ),
                          ),
                        ),
                        child: isBusy
                            ? SizedBox.square(
                                dimension: sizing.iconXs,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                tr('Rejoin'),
                                style: sizing.text.buttonLabelCompact,
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Outlined and quiet. Withdrawing is the escape hatch, not the thing the card
/// is asking for — the patient asked for a doctor and is still waiting on one.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.isBusy, required this.onPressed});

  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return SizedBox(
      height: sizing.buttonHeightCompact,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.danger,
          side: BorderSide(color: AppColors.danger),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sizing.radiusMd),
          ),
        ),
        child: isBusy
            ? SizedBox.square(
                dimension: sizing.iconXs,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.danger),
                ),
              )
            : Text(
                tr('Cancel'),
                style: sizing.text.buttonLabelCompact.copyWith(
                  color: AppColors.danger,
                ),
              ),
      ),
    );
  }
}
