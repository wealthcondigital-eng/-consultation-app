import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../domain/entities/doctor.dart';

/// A doctor in the listing: identity above a rule, fee and booking below it.
class DoctorListCard extends StatelessWidget {
  const DoctorListCard({
    super.key,
    required this.doctor,
    required this.onBook,
    this.onTap,
    this.actionLabel,
  });

  final Doctor doctor;
  final VoidCallback onBook;
  final VoidCallback? onTap;

  /// Overrides the button's label where booking does something other than
  /// putting an appointment in the diary.
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusLg);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(sizing.cardPadding),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(width: sizing.hairline, color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Identity(doctor: doctor),
              SizedBox(height: sizing.spacingMd),
              Container(height: sizing.hairline, color: AppColors.border),
              SizedBox(height: sizing.spacingMd),
              _Footer(
                fee: doctor.formattedFee,
                actionLabel: actionLabel ?? 'Book Appointment',
                onBook: onBook,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fee and booking button, side by side when they fit and stacked when they
/// do not — the label is too long to sit beside the fee on a small phone.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.fee,
    required this.actionLabel,
    required this.onBook,
  });

  final String fee;
  final String actionLabel;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final feeBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Consultation Fee'), style: sizing.text.fieldCaption),
            SizedBox(height: sizing.spacingXxs * 0.5),
            Text(fee, style: sizing.text.listTitle),
          ],
        );

        final button = AppButton.primary(
          label: actionLabel,
          size: AppButtonSize.compact,
          onPressed: onBook,
        );

        if (constraints.maxWidth < sizing.w(300)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              feeBlock,
              SizedBox(height: sizing.spacingSm),
              button,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            feeBlock,
            Flexible(child: button),
          ],
        );
      },
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      children: [
        RemoteAvatar(
          path: doctor.photoUrl,
          initials: initialsOf(doctor.name),
          size: sizing.avatarSize,
          semanticLabel: doctor.name,
        ),
        SizedBox(width: sizing.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doctor.name,
                style: sizing.text.listTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                tr(doctor.speciality),
                style: sizing.text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: sizing.spacingXxs * 0.5),
              _MetaRow(doctor: doctor),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      children: [
        Flexible(
          child: Text(
            doctor.experienceLabel,
            style: sizing.text.metaLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        Container(
          width: sizing.r(3),
          height: sizing.r(3),
          decoration: BoxDecoration(
            color: AppColors.textTertiary,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        Icon(
          Icons.star_rounded,
          size: sizing.iconXs * 0.75,
          color: AppColors.primary,
        ),
        SizedBox(width: sizing.spacingXxs * 0.5),
        Text(
          doctor.formattedRating,
          style: sizing.text.metaLabel.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (doctor.isAvailableNow) ...[
          SizedBox(width: sizing.spacingXs),
          const _AvailableDot(),
        ],
      ],
    );
  }
}

/// A small green dot marking a doctor who can take a call right now.
class _AvailableDot extends StatelessWidget {
  const _AvailableDot();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      label: tr('Available now'),
      child: Container(
        width: sizing.r(6),
        height: sizing.r(6),
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
