import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import 'remote_avatar.dart';
import '../l10n/tr.dart';

/// The banner at the top of a profile: photo, name, and one line under it.
///
/// Shared by both roles. Their profiles had grown apart — a centred avatar over
/// white on one, a row on a tinted card on the other — even though they are the
/// same screen doing the same job, and a patient who is also a doctor saw two
/// different apps. This is the one header, on the brand gradient.
///
/// It bleeds under the status bar rather than sitting below a white top bar,
/// which is what makes a profile read as *yours* rather than as another list.
class ProfileHeroHeader extends StatelessWidget {
  const ProfileHeroHeader({
    super.key,
    required this.name,
    required this.initials,
    this.subtitle,
    this.badge,
    this.photoPath,
    this.onChangePhoto,
    this.isSavingPhoto = false,
    this.trailing,
  });

  /// Falls back to a neutral title when there is no name on file yet, so the
  /// header never renders an empty line where a name should be.
  final String name;

  /// One or two letters, behind the photo.
  final String initials;

  /// Phone number, email, or a speciality — whatever identifies this account
  /// at a glance.
  final String? subtitle;

  /// A short pill under the name: `Verified doctor`, `Under review`. Null when
  /// there is nothing to certify.
  final Widget? badge;

  /// An API path — see [RemoteAvatar]. Not a public URL: the photo route sits
  /// behind the same bearer token as the record it belongs to.
  final String? photoPath;

  /// Null when this profile's photo is not editable from here, which is what
  /// removes the camera badge rather than leaving one that does nothing.
  final VoidCallback? onChangePhoto;

  /// True while a photo is being uploaded or removed. The spinner sits over the
  /// avatar rather than over the screen — the rest of the profile is still
  /// perfectly readable, and the thing that is changing is the photo.
  final bool isSavingPhoto;

  /// An action in the top-right corner of the banner, e.g. Edit.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final avatarSize = sizing.r(88);
    final onChangePhoto = this.onChangePhoto;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingMd,
        sizing.screenPaddingH,
        sizing.spacingXl,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.brandSweep,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(sizing.r(28)),
        ),
      ),
      child: Column(
        children: [
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing)
          else
            SizedBox(height: sizing.spacingSm),
          SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: Stack(
              children: [
                // The ring is what separates a dark photo from the gradient
                // behind it; without it a portrait taken indoors bleeds into
                // the banner.
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: sizing.r(3),
                    ),
                  ),
                  child: ClipOval(
                    child: RemoteAvatar(
                      path: photoPath,
                      initials: initials,
                      size: avatarSize,
                      semanticLabel: tr('{name} profile photo', {'name': name}),
                    ),
                  ),
                ),
                if (isSavingPhoto)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  ),
                if (onChangePhoto != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _CameraBadge(
                      size: sizing.r(30),
                      onTap: isSavingPhoto ? null : onChangePhoto,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: sizing.spacingSm),
          Text(
            name.trim().isEmpty ? tr('Your profile') : name,
            style: sizing.text.headline.copyWith(
              fontSize: sizing.sp(20),
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle case final subtitle? when subtitle.isNotEmpty) ...[
            SizedBox(height: sizing.spacingXxs),
            Text(
              tr(subtitle),
              style: sizing.text.screenSubtitle.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (badge case final badge?) ...[
            SizedBox(height: sizing.spacingSm),
            badge,
          ],
        ],
      ),
    );
  }
}

/// A pill on the banner, for a status that is worth stating on sight.
class ProfileHeroBadge extends StatelessWidget {
  const ProfileHeroBadge({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingSm,
        vertical: sizing.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(sizing.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: sizing.iconXs * 0.85, color: Colors.white),
          SizedBox(width: sizing.spacingXxs),
          Text(
            tr(label),
            style: sizing.text.metaLabel.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraBadge extends StatelessWidget {
  const _CameraBadge({required this.size, required this.onTap});

  final double size;

  /// Null while an upload is in flight, so a second tap cannot start another.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      button: true,
      label: tr('Change profile photo'),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onTap == null ? AppColors.textTertiary : AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: AppShadows.badge,
          ),
          child: Icon(
            Icons.photo_camera_rounded,
            size: sizing.iconXs * 0.85,
            color: onTap == null ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
