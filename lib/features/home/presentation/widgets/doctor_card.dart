import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../doctors/domain/entities/doctor.dart';

/// A doctor in the listing: avatar, name, credentials and rating.
class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor, required this.onTap});

  final Doctor doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusMd);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(sizing.tilePadding),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(width: sizing.hairline, color: AppColors.border),
          ),
          child: Row(
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
                  size: sizing.iconMd,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(width: sizing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      style: sizing.text.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sizing.spacingXxs * 0.5),
                    Text(
                      doctor.credentials,
                      style: sizing.text.cardSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: sizing.spacingXs),
              _RatingPill(rating: doctor.formattedRating),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});

  final String rating;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingXs,
        vertical: sizing.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(sizing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: sizing.iconXs * 0.8,
            color: AppColors.primary,
          ),
          SizedBox(width: sizing.spacingXxs * 0.5),
          Text(rating, style: sizing.text.ratingValue),
        ],
      ),
    );
  }
}
