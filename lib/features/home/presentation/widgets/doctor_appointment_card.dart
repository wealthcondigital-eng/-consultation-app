import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../consultation/presentation/widgets/consultation_mode_sheet.dart';
import '../../domain/entities/doctor_appointment.dart';
import '../../../../core/l10n/tr.dart';

/// One consultation on the doctor's schedule: who, how, when, and the way in.
class DoctorAppointmentCard extends StatelessWidget {
  const DoctorAppointmentCard({
    super.key,
    required this.appointment,
    required this.onStart,
    this.onOpenPatient,
  });

  final DoctorAppointment appointment;

  /// Joins the consultation.
  final VoidCallback onStart;

  /// Opens who the patient is. Null leaves the row inert, which is what a
  /// preview or a test that does not care about it gets.
  final VoidCallback? onOpenPatient;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Identity(appointment: appointment, onTap: onOpenPatient),

          // What the patient said they want to discuss. The reason the doctor
          // is looking at this card at all, and on an anonymous consultation
          // the only thing they are told about the person — a card that showed
          // an alias, a time and nothing else asked them to accept a call
          // about they knew not what.
          if (appointment.concern case final concern?) ...[
            SizedBox(height: sizing.spacingSm),
            _Concern(text: concern),
          ],
          SizedBox(height: sizing.spacingSm),
          Container(height: sizing.hairline, color: AppColors.dividerFaint),
          SizedBox(height: sizing.spacingSm),
          _Footer(appointment: appointment, onStart: onStart),
        ],
      ),
    );
  }
}

/// Who the consultation is with, and how it will be held.
class _Identity extends StatelessWidget {
  const _Identity({required this.appointment, this.onTap});

  final DoctorAppointment appointment;

  /// Opens the patient's details. The name is the tap target rather than the
  /// whole card: the card's own action is the call, and a doctor reaching for
  /// Start Call must not open a sheet by landing slightly left of it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final identity = Row(
      children: [
        _PatientAvatar(appointment: appointment),
        SizedBox(width: sizing.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      appointment.patientName,
                      style: sizing.text.listTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (appointment.isAnonymous) ...[
                    SizedBox(width: sizing.spacingXxs),
                    Semantics(
                      label: tr('Anonymous booking'),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: sizing.iconXs * 0.8,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  // A booking and a patient waiting on the line look the same
                  // on a card that only shows a time. They are not the same
                  // thing to a doctor deciding what to do next.
                  if (appointment.isScheduled) ...[
                    SizedBox(width: sizing.spacingXxs),
                    Semantics(
                      label: tr('Booked appointment'),
                      child: Icon(
                        Icons.event_available_rounded,
                        size: sizing.iconXs * 0.8,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: sizing.spacingXxs * 0.5),
              Row(
                children: [
                  Icon(
                    iconForConsultationMode(appointment.mode),
                    size: sizing.iconXs * 0.8,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(width: sizing.spacingXxs),
                  Flexible(
                    child: Text(
                      tr(appointment.modeLabel),
                      style: sizing.text.metaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onTap != null) ...[
          SizedBox(width: sizing.spacingXxs),
          Icon(
            Icons.chevron_right_rounded,
            size: sizing.iconSm,
            color: AppColors.textTertiary,
          ),
        ],
      ],
    );

    if (onTap == null) return identity;

    return Semantics(
      button: true,
      label: tr('View {name}', {'name': appointment.patientName}),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(sizing.radiusMd),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: sizing.spacingXxs * 0.5),
          child: identity,
        ),
      ),
    );
  }
}

/// When it starts, where it stands, and the way in.
///
/// The button is a fixed width so it lands in the same place on every card in
/// the list, whether it says Start Call or View. It stacks under the time on a
/// screen too narrow for both.
class _Footer extends StatelessWidget {
  const _Footer({required this.appointment, required this.onStart});

  final DoctorAppointment appointment;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final when = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appointment.timeLabel,
              style: sizing.text.fieldValue.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: sizing.spacingXs),
            // The badge gives way first: the time is the part that must stay
            // readable when there is not room for both.
            Flexible(child: _StatusBadge(status: appointment.status)),
          ],
        );

        final isJoinable = appointment.isJoinable();

        final action = SizedBox(
          width: sizing.w(104),
          child: isJoinable
              ? AppButton.primary(
                  label: 'Start Call',
                  size: AppButtonSize.compact,
                  onPressed: onStart,
                )
              // A booking on a later day has no room to open, so the button
              // says what it does. It used to read "View" on a card the doctor
              // could equally well be about to take a call from.
              : AppButton.outline(
                  label: 'Details',
                  size: AppButtonSize.compact,
                  onPressed: onStart,
                ),
        );

        if (constraints.maxWidth < sizing.w(280)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              when,
              SizedBox(height: sizing.spacingSm),
              action,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: when),
            action,
          ],
        );
      },
    );
  }
}

class _PatientAvatar extends StatelessWidget {
  const _PatientAvatar({required this.appointment});

  final DoctorAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    // An alias gets the masked glyph and never a photo — a face identifies as
    // surely as a name, and the server sends none for an anonymous booking.
    if (appointment.isAnonymous) {
      return Container(
        width: sizing.avatarSize,
        height: sizing.avatarSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.anonymousAccent.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_off_rounded,
          size: sizing.iconMd,
          color: AppColors.anonymousAccent.icon,
        ),
      );
    }

    // The patient's current photo, with their initials under it while it
    // loads or when they have not added one. A name that is still the phone
    // number they booked with has no initials worth drawing, so it falls back
    // to the person glyph.
    final initials = initialsOf(appointment.patientName);
    final hasInitials = RegExp(r'[A-Za-z]').hasMatch(initials);

    if (appointment.patientPhotoUrl == null && !hasInitials) {
      return Container(
        width: sizing.avatarSize,
        height: sizing.avatarSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.avatarSurface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_rounded,
          size: sizing.iconMd,
          color: AppColors.textSecondary,
        ),
      );
    }

    return RemoteAvatar(
      path: appointment.patientPhotoUrl,
      initials: hasInitials ? initials : '?',
      size: sizing.avatarSize,
      semanticLabel: appointment.patientName,
    );
  }
}

/// `Waiting` / `Confirmed` — a pill whose colour carries the urgency.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final DoctorAppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final (surface, foreground) = switch (status) {
      DoctorAppointmentStatus.confirmed => (
        AppColors.primarySurface,
        AppColors.primaryDeep,
      ),
      DoctorAppointmentStatus.waiting => (
        AppColors.badgeSurface,
        AppColors.success,
      ),
      DoctorAppointmentStatus.inProgress => (
        AppColors.successSurface,
        AppColors.success,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingXs,
        vertical: sizing.spacingXxs * 0.75,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(sizing.radiusPill),
      ),
      child: Text(
        tr(status.label),
        style: sizing.text.metaLabel.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// The patient's own words on why they are consulting.
///
/// Set apart on a tinted panel rather than run in as another grey meta line:
/// everything else on the card is a fact about the appointment, and this is the
/// only thing on it the doctor actually has to read.
///
/// Clamped to three lines. A long note is not something to scroll on a list of
/// cards, and the whole of it is on the consultation itself.
class _Concern extends StatelessWidget {
  const _Concern({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingSm,
        vertical: sizing.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote_rounded,
            size: sizing.iconXs * 0.9,
            color: AppColors.textTertiary,
          ),
          SizedBox(width: sizing.spacingXs),
          Expanded(
            child: Text(
              text,
              style: sizing.text.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
