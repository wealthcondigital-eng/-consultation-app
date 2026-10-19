import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/widgets/profile_hero_header.dart';
import '../../../home/domain/entities/doctor_dashboard.dart';

/// Who the doctor is, at the top of their profile: name, speciality, whether
/// they are taking calls. The day's figures sit in their own section right
/// under it — see `DoctorProfileView`.
///
/// Built on the shared [ProfileHeroHeader], which is also what the patient's
/// profile uses. The two had grown apart — a white card with a row here, a
/// centred column on plain white there — even though they are the same screen
/// doing the same job, and a doctor who is also a patient saw two apps.
///
/// What is specific to a doctor stays here: the online pill, which no patient
/// has.
class DoctorProfileHeader extends StatelessWidget {
  const DoctorProfileHeader({
    super.key,
    required this.dashboard,
    required this.onEdit,
    required this.onChangePhoto,
    this.isSavingPhoto = false,
  });

  final DoctorDashboard dashboard;
  final VoidCallback onEdit;

  /// Opens the camera-or-gallery sheet.
  final VoidCallback onChangePhoto;

  /// True while a photo is in flight. The spinner sits over the avatar rather
  /// than over the card.
  final bool isSavingPhoto;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileHeroHeader(
          name: dashboard.doctorName,
          initials: _initialsOf(dashboard.doctorName),
          subtitle: dashboard.speciality,
          photoPath: dashboard.photoUrl,
          isSavingPhoto: isSavingPhoto,
          onChangePhoto: onChangePhoto,
          trailing: _EditButton(onTap: onEdit),
          // Two facts answering different questions: whether patients can
          // reach this doctor *now*, and whether a reviewer has accepted their
          // credentials at all. Wrapped, because at 320pt they do not fit on
          // one line.
          badge: Wrap(
            spacing: sizing.spacingXs,
            runSpacing: sizing.spacingXxs,
            alignment: WrapAlignment.center,
            children: [
              ProfileHeroBadge(
                icon: dashboard.isOnline
                    ? Icons.podcasts_rounded
                    : Icons.do_not_disturb_on_rounded,
                label: dashboard.isOnline ? 'Online' : 'Offline',
              ),
              const ProfileHeroBadge(
                icon: Icons.verified_rounded,
                label: 'Verified',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// `Dr. Amit Verma` -> `AV`. The title is dropped: every doctor has one, so
  /// a circle full of `D`s tells you nothing.
  static String _initialsOf(String name) {
    final words = name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && !_isTitle(word))
        .toList();

    if (words.isEmpty) return '?';

    final first = words.first[0];
    final last = words.length > 1 ? words.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  static bool _isTitle(String word) {
    const titles = {'dr', 'dr.', 'prof', 'prof.', 'mr', 'mr.', 'mrs', 'mrs.'};
    return titles.contains(word.toLowerCase());
  }
}

/// A quiet action on the banner. White on the gradient rather than a filled
/// button: editing is available, not being asked for.
class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      button: true,
      label: tr('Edit profile'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(sizing.radiusPill),
        child: Container(
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
              Icon(
                Icons.edit_rounded,
                size: sizing.iconXs * 0.85,
                color: Colors.white,
              ),
              SizedBox(width: sizing.spacingXxs),
              Text(
                tr('Edit'),
                style: sizing.text.metaLabel.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
