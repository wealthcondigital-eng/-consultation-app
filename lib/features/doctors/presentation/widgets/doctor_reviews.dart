import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/doctor_review.dart';

/// What patients have written about a doctor, on their profile.
///
/// The other half of the star on the listing card. An average out of five with
/// nothing behind it asks a patient to choose who to discuss their health with
/// on the strength of one number and no sentences — and until reviews were
/// stored at all, that number was the only thing there was.
class DoctorReviews extends StatelessWidget {
  const DoctorReviews({super.key, required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (doctor.reviews.isEmpty) {
      return _Empty(doctor: doctor);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final review in doctor.reviews) ...[
          if (review != doctor.reviews.first)
            SizedBox(height: sizing.spacingSm),
          _ReviewCard(review: review),
        ],
      ],
    );
  }
}

/// Nobody has written anything yet.
///
/// Said plainly rather than left as a missing section. A doctor with no reviews
/// is a new doctor, not a bad one, and a heading over a blank card reads as the
/// screen having failed to load.
class _Empty extends StatelessWidget {
  const _Empty({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Text(
        doctor.reviewCount == 0
            ? tr('No reviews yet. Yours would be the first.')
            // Rated, but nobody has written anything: the average is real and
            // the list is empty, and saying so is better than implying the
            // reviews failed to load.
            : tr('Rated {summary}, with no written reviews yet.', {
                'summary': doctor.reviewSummary.toLowerCase(),
              }),
        style: sizing.text.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final DoctorReview review;

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
          Row(
            children: [
              _Stars(rating: review.rating),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Text(
                  review.authorLabel,
                  style: sizing.text.metaLabel.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(review.dateLabel, style: sizing.text.caption),
            ],
          ),
          SizedBox(height: sizing.spacingXs),
          Text(
            review.comment,
            style: sizing.text.bodySmall.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      label: tr('{rating} out of 5', {'rating': rating}),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var star = 1; star <= 5; star++)
            Icon(
              star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: sizing.iconXs * 0.9,
              color: star <= rating
                  ? AppColors.ratingStar
                  : AppColors.textTertiary,
            ),
        ],
      ),
    );
  }
}
