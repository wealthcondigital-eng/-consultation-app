import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../doctors/domain/entities/doctor.dart';

/// Who the appointment is with, above the day and time being chosen.
class ScheduleDoctorCard extends StatelessWidget {
  const ScheduleDoctorCard({super.key, required this.doctor});

  final Doctor doctor;

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
                    Flexible(
                      child: Text(
                        doctor.name,
                        style: sizing.text.sectionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (doctor.isAvailableNow) ...[
                      SizedBox(width: sizing.spacingXxs * 1.5),
                      Container(
                        width: sizing.r(8),
                        height: sizing.r(8),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: sizing.spacingXxs),
                Text(
                  tr(doctor.speciality),
                  style: sizing.text.screenSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: sizing.spacingXxs),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: sizing.iconXs * 0.9,
                      color: const Color(0xFFF59E0B),
                    ),
                    SizedBox(width: sizing.spacingXxs),
                    Text(doctor.formattedRating, style: sizing.text.fieldAffix),
                    SizedBox(width: sizing.spacingXxs),
                    Flexible(
                      child: Text(
                        doctor.experienceLabel,
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
        ],
      ),
    );
  }
}
