import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/doctor_review.dart';
import '../controllers/doctor_reviews_controller.dart';

/// What patients wrote about this doctor, for the doctor.
///
/// **Named**, unlike the same rows in the public directory — see
/// [DoctorReview]. A doctor reading their own feedback needs to know which
/// consultation a complaint came from; a patient browsing the directory has no
/// business learning who else consulted somebody. Anonymous reviews stay
/// anonymous on both.
class DoctorReviewsScreen extends StatefulWidget {
  const DoctorReviewsScreen({super.key});

  @override
  State<DoctorReviewsScreen> createState() => _DoctorReviewsScreenState();
}

class _DoctorReviewsScreenState extends State<DoctorReviewsScreen> {
  late final DoctorReviewsController _controller =
      sl<DoctorReviewsController>();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppTopBar(
              title: 'Patient Reviews',
              variant: AppTopBarVariant.outlined,
              centerTitle: true,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  if (_controller.isInitialLoad) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_controller.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.rate_review_outlined,
                      title: 'No reviews yet',
                      message:
                          'What patients write after a consultation appears '
                          'here.',
                    );
                  }

                  return AppRefreshIndicator(
                    onRefresh: _controller.load,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        sizing.screenPaddingH,
                        sizing.spacingSm,
                        sizing.screenPaddingH,
                        sizing.spacingXxl,
                      ),
                      children: [
                        // Above the rows rather than instead of them: a refresh
                        // that failed must not take away reviews that loaded
                        // perfectly well a minute ago.
                        if (_controller.errorMessage case final message?) ...[
                          AppInlineError(
                            message: message,
                            onRetry: _controller.load,
                          ),
                          SizedBox(height: sizing.spacingSm),
                        ],
                        _Summary(
                          average: _controller.average,
                          count: _controller.reviews.length,
                        ),
                        SizedBox(height: sizing.spacingMd),
                        for (final review in _controller.reviews) ...[
                          if (review != _controller.reviews.first)
                            SizedBox(height: sizing.spacingSm),
                          _ReviewCard(review: review),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The average of what is on this page, and how many wrote something.
class _Summary extends StatelessWidget {
  const _Summary({required this.average, required this.count});

  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            average.toStringAsFixed(1),
            style: sizing.text.screenTitle.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Stars(rating: average.round()),
                SizedBox(height: sizing.spacingXxs),
                // Says which average this is. The dashboard's counts every
                // rating, including the ones nobody wrote anything on, so the
                // two numbers differ and a bare "rating" would read as one of
                // them contradicting the other.
                Text(
                  count == 1
                      ? tr('From 1 written review')
                      : tr('From {count} written reviews', {'count': count}),
                  style: sizing.text.cardSubtitle,
                ),
              ],
            ),
          ),
        ],
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
              // Null on an anonymous review, so the avatar falls back to its
              // glyph. The API withholds the path rather than the app hiding
              // it: a face identifies as surely as a name.
              RemoteAvatar(
                path: review.photoUrl,
                initials: review.initials,
                size: sizing.avatarSize,
                background: review.isAnonymous
                    ? AppColors.anonymousAccent.surface
                    : AppColors.avatarSurface,
                semanticLabel: tr('{name} profile photo', {
                  'name': tr(review.authorName),
                }),
              ),
              SizedBox(width: sizing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tr(review.authorName),
                            style: sizing.text.listTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (review.isAnonymous) ...[
                          SizedBox(width: sizing.spacingXxs),
                          Semantics(
                            label: tr('Anonymous consultation'),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: sizing.iconXs * 0.8,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: sizing.spacingXxs * 0.5),
                    Text(review.detailLabel, style: sizing.text.metaLabel),
                  ],
                ),
              ),
              SizedBox(width: sizing.spacingXs),
              _Stars(rating: review.rating),
            ],
          ),
          SizedBox(height: sizing.spacingSm),
          Text(review.comment, style: sizing.text.bodySmall),
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
              size: sizing.iconXs,
              color: star <= rating
                  ? AppColors.ratingStar
                  : AppColors.textTertiary,
            ),
        ],
      ),
    );
  }
}
