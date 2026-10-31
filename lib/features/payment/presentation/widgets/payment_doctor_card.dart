import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';

/// Who the patient is paying, and for what kind of consultation.
class PaymentDoctorCard extends StatelessWidget {
  const PaymentDoctorCard({
    super.key,
    required this.doctor,
    required this.mode,
    this.scheduledFor,
  });

  final Doctor doctor;
  final ConsultationMode mode;

  /// The booked day and time, when the consultation is for later.
  final String? scheduledFor;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          RemoteAvatar(
            path: doctor.photoUrl,
            initials: initialsOf(doctor.name),
            size: sizing.avatarSizeLarge,
            semanticLabel: doctor.name,
          ),
          SizedBox(width: sizing.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        doctor.name,
                        style: sizing.text.sectionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: sizing.spacingXs),
                    Icon(
                      Icons.star_rounded,
                      size: sizing.iconXs * 0.9,
                      color: const Color(0xFFF59E0B),
                    ),
                    SizedBox(width: sizing.spacingXxs),
                    Text(doctor.formattedRating, style: sizing.text.fieldAffix),
                  ],
                ),
                SizedBox(height: sizing.spacingXxs),
                Text(
                  tr(doctor.speciality),
                  style: sizing.text.screenSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: sizing.spacingXxs * 1.5),
                Row(
                  children: [
                    Icon(
                      Icons.videocam_rounded,
                      size: sizing.iconXs * 0.9,
                      color: AppColors.primaryVivid,
                    ),
                    SizedBox(width: sizing.spacingXxs * 1.5),
                    Flexible(
                      child: Text(
                        tr(mode.label),
                        style: sizing.text.linkSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (scheduledFor case final scheduledFor?) ...[
                  SizedBox(height: sizing.spacingXxs),
                  Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: sizing.iconXs * 0.9,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: sizing.spacingXxs * 1.5),
                      Flexible(
                        child: Text(
                          scheduledFor,
                          style: sizing.text.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
