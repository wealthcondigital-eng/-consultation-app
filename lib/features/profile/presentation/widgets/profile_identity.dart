import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../domain/entities/patient_account.dart';

/// Avatar, name and email at the top of My Profile.
class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity({
    super.key,
    required this.account,
    required this.onChangePhoto,
    this.isSavingPhoto = false,
  });

  final PatientAccount account;
  final VoidCallback onChangePhoto;

  /// True while a photo is being uploaded or removed. The spinner sits over the
  /// avatar rather than over the screen — the rest of the profile is still
  /// perfectly readable, and the thing that is changing is the photo.
  final bool isSavingPhoto;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final avatarSize = sizing.r(100);

    return Column(
      children: [
        SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: Stack(
            children: [
              RemoteAvatar(
                path: account.avatarUrl,
                initials: account.initials,
                size: avatarSize,
                semanticLabel: tr('{name} profile photo', {
                  'name': account.fullName,
                }),
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
              Positioned(
                right: 0,
                bottom: 0,
                child: _CameraBadge(
                  size: sizing.r(32),
                  onTap: isSavingPhoto ? null : onChangePhoto,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: sizing.spacingMd),
        Text(
          account.fullName.isEmpty ? tr('Your profile') : account.fullName,
          style: sizing.text.headline.copyWith(fontSize: sizing.sp(20)),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: sizing.spacingXxs),
        Text(
          // The phone number rather than an empty line. Email is optional and
          // often blank; the number is the account's identity and always there.
          account.email.isEmpty ? account.phoneNumber : account.email,
          style: sizing.text.screenSubtitle,
          textAlign: TextAlign.center,
        ),
      ],
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
            color: onTap == null
                ? AppColors.textTertiary
                : AppColors.primaryVivid,
            shape: BoxShape.circle,
            // The white ring is what lifts the badge off the photo.
            border: Border.all(color: AppColors.surface, width: sizing.r(3)),
            boxShadow: AppShadows.badge,
          ),
          child: Icon(
            Icons.photo_camera_rounded,
            size: sizing.iconXs * 0.85,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
