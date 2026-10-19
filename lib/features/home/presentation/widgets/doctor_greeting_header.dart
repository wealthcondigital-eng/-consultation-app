import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import 'waving_hand.dart';
import '../../../../core/l10n/tr.dart';

/// The top of the doctor's home: a greeting for the time of day, who they are,
/// and their photo as the way into their profile.
///
/// The counterpart of `PatientGreetingHeader` — same gradient, same shape —
/// so a doctor who is also a patient does not move between two apps. It used
/// to be a centred name and speciality with nothing to say to the person
/// reading it.
class DoctorGreetingHeader extends StatelessWidget {
  const DoctorGreetingHeader({
    super.key,
    required this.doctorName,
    required this.speciality,
    required this.isOnline,
    required this.onOpenProfile,
    this.photoPath,
    this.now,
  });

  /// Including the title, e.g. `Dr. Amit Verma`.
  final String doctorName;

  final String speciality;

  /// Drawn as a dot on the avatar, so the state is readable even with the
  /// dial scrolled out of view.
  final bool isOnline;

  final VoidCallback onOpenProfile;

  /// The API path the photo is served from, or null when there is none.
  final String? photoPath;

  /// Pinned in a test so the greeting does not depend on when it runs.
  final DateTime? now;

  /// `Good morning` / `Good afternoon` / `Good evening`.
  static String greetingFor(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final greeting = tr(greetingFor(now ?? DateTime.now()));
    final name = doctorName.trim().isEmpty ? tr('Doctor') : doctorName.trim();
    final greetingStyle = sizing.text.bodySmall.copyWith(
      color: Colors.white.withValues(alpha: 0.85),
      fontWeight: FontWeight.w600,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingLg,
        sizing.screenPaddingH,
        sizing.spacingXl,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.brandSweep,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(sizing.r(28)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: '$greeting ',
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: WavingHand(style: greetingStyle),
                      ),
                    ],
                  ),
                  style: greetingStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  semanticsLabel: greeting,
                ),
                SizedBox(height: sizing.spacingXxs * 0.5),
                Text(
                  name,
                  style: sizing.text.navTitle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (speciality.trim().isNotEmpty) ...[
                  SizedBox(height: sizing.spacingXs),
                  _SpecialityChip(label: speciality.trim()),
                ],
              ],
            ),
          ),
          SizedBox(width: sizing.spacingSm),
          const NotificationBell(),
          SizedBox(width: sizing.spacingXs),
          Semantics(
            button: true,
            label: tr('Your profile'),
            excludeSemantics: true,
            child: InkWell(
              onTap: onOpenProfile,
              customBorder: const CircleBorder(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.all(sizing.r(2)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: sizing.r(2),
                      ),
                    ),
                    child: RemoteAvatar(
                      path: photoPath,
                      initials: initialsOf(name),
                      size: sizing.avatarSize,
                    ),
                  ),
                  Positioned(
                    right: sizing.r(1),
                    bottom: sizing.r(1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: sizing.r(13),
                      height: sizing.r(13),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline
                            ? AppColors.successStrong
                            : AppColors.textTertiary,
                        border: Border.all(
                          color: AppColors.primaryEnd,
                          width: sizing.r(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `Cardiology`, on a frosted pill.
class _SpecialityChip extends StatelessWidget {
  const _SpecialityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingSm,
        vertical: sizing.spacingXxs * 0.75,
      ),
      decoration: BoxDecoration(
        color: AppColors.onBrandSurface,
        borderRadius: BorderRadius.circular(sizing.radiusPill),
        border: Border.all(color: AppColors.onBrandBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.medical_services_rounded,
            size: sizing.iconXs * 0.8,
            color: Colors.white,
          ),
          SizedBox(width: sizing.spacingXxs),
          Flexible(
            child: Text(
              tr(label),
              style: sizing.text.metaLabel.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
