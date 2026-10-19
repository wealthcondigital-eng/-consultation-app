import 'package:flutter/material.dart';

import '../../../../core/format/app_date_format.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../../../core/widgets/remote_avatar.dart';
import 'waving_hand.dart';
import '../../../../core/l10n/tr.dart';

/// The top of the patient dashboard: who they are, and where to start.
///
/// The running totals that used to sit here — consults, doctors seen, money
/// spent — are a record, and they live on the profile. What is left is the
/// greeting, today's date, and a search bar into the doctor directory, which is
/// the thing most visits are for.
///
/// It is set on the brand gradient and bleeds to the top of the screen, so the
/// status bar area belongs to the app rather than reading as a strip of unused
/// white above a card.
class PatientGreetingHeader extends StatelessWidget {
  const PatientGreetingHeader({
    super.key,
    required this.firstName,
    required this.onOpenProfile,
    this.onSearch,
    this.avatarPath,
    this.initials,
    this.now,
  });

  /// What to call them. Null before onboarding has a name to use.
  final String? firstName;

  final VoidCallback onOpenProfile;

  /// Opens the doctor directory. Hides the search bar when null.
  final VoidCallback? onSearch;

  /// The API path the photo is served from, or null when there is none.
  final String? avatarPath;

  /// One or two letters. Null before the patient has a name on file, which is
  /// when the glyph is shown instead.
  final String? initials;

  /// Injectable so a test can pin the time of day.
  final DateTime? now;

  /// `Good morning` / `Good afternoon` / `Good evening`.
  static String salutationAt(DateTime time) => switch (time.hour) {
    < 5 => 'Good evening',
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final time = now ?? DateTime.now();
    final name = firstName?.trim();
    final hasName = name != null && name.isNotEmpty;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.brandSweep,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(sizing.r(28)),
        ),
      ),
      child: Stack(
        children: [
          // Two soft rings for depth. Decoration only, behind everything.
          Positioned(
            right: -sizing.r(60),
            top: -sizing.r(50),
            child: _Ring(size: sizing.r(190)),
          ),
          Positioned(
            left: -sizing.r(40),
            bottom: -sizing.r(70),
            child: _Ring(size: sizing.r(150)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              sizing.screenPaddingH,
              sizing.spacingLg,
              sizing.screenPaddingH,
              sizing.spacingXl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // `Sat, 3 Oct` in a pill — orientation before
                          // greeting.
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: sizing.spacingXs,
                              vertical: sizing.spacingXxs / 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.onBrandSurface,
                              borderRadius: BorderRadius.circular(
                                sizing.radiusPill,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wb_sunny_rounded,
                                  size: sizing.iconXs * 0.8,
                                  color: AppColors.onBrand,
                                ),
                                SizedBox(width: sizing.spacingXxs),
                                Text(
                                  '${AppDateFormat.weekdayShort(time)}, '
                                  '${AppDateFormat.dayMonth(time)}',
                                  style: sizing.text.metaLabel.copyWith(
                                    color: AppColors.onBrand,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: sizing.spacingXs),
                          Text.rich(
                            TextSpan(
                              text: tr(salutationAt(time)),
                              children: [
                                const TextSpan(text: ' '),
                                // Inline rather than a Row so the hand stays
                                // beside the words however they wrap.
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: WavingHand(
                                    style: sizing.text.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                            style: sizing.text.bodySmall.copyWith(
                              color: AppColors.onBrandMuted,
                              fontWeight: FontWeight.w600,
                            ),
                            semanticsLabel: tr(salutationAt(time)),
                          ),
                          Text(
                            hasName ? name : tr('there'),
                            style: sizing.text.screenTitle.copyWith(
                              color: AppColors.onBrand,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: sizing.spacingSm),
                    // Beside the avatar rather than in a bar of its own: the
                    // header is where the patient already looks.
                    const NotificationBell(),
                    SizedBox(width: sizing.spacingXs),
                    _ProfileAvatar(
                      avatarPath: avatarPath,
                      initials: initials,
                      onTap: onOpenProfile,
                    ),
                  ],
                ),
                SizedBox(height: sizing.spacingXxs),
                Text(
                  tr('How can we help you today?'),
                  style: sizing.text.bodySmall.copyWith(
                    color: AppColors.onBrandMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (onSearch case final onSearch?) ...[
                  SizedBox(height: sizing.spacingMd),
                  _SearchBar(onTap: onSearch),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: size * 0.12,
          ),
        ),
      ),
    );
  }
}

/// A search field that is really a button: tapping it opens the directory,
/// which has the real search box and the filters.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusMd);

    return Semantics(
      button: true,
      label: tr('Search doctors'),
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: radius,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            height: sizing.inputHeight,
            padding: EdgeInsets.symmetric(horizontal: sizing.spacingMd),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: sizing.iconMd,
                  color: AppColors.primary,
                ),
                SizedBox(width: sizing.spacingSm),
                Expanded(
                  child: Text(
                    tr('Search doctors, specialities…'),
                    style: sizing.text.fieldPlaceholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(sizing.spacingXxs),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(sizing.radiusSm),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: sizing.iconSm,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarPath,
    required this.initials,
    required this.onTap,
  });

  final String? avatarPath;
  final String? initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      button: true,
      label: tr('Your profile'),
      // The photo and its initials fallback are decoration for one control,
      // and the avatar labels itself with the patient's name — so without this
      // a screen reader announced the name where the destination belonged.
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: EdgeInsets.all(sizing.r(2)),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: sizing.r(2),
            ),
          ),
          child: switch (initials) {
            final initials? when initials != '?' => RemoteAvatar(
              path: avatarPath,
              initials: initials,
              size: sizing.avatarSize,
            ),
            // No name on file yet, so there are no initials worth drawing.
            _ => Container(
              width: sizing.avatarSize,
              height: sizing.avatarSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                size: sizing.iconMd,
                color: AppColors.primary,
              ),
            ),
          },
        ),
      ),
    );
  }
}
