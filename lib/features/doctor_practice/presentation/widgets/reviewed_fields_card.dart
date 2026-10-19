import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/profile_section.dart';
import '../../domain/entities/doctor_practice_profile.dart';

/// The three fields the doctor cannot edit here, and why.
///
/// Shown rather than hidden. A form that silently omits the registration number
/// looks like a form that lost it, and the first support question is "where has
/// my council number gone". Saying that these were reviewed, and what to do to
/// change one, answers it once on the screen where it comes up.
class ReviewedFieldsCard extends StatelessWidget {
  const ReviewedFieldsCard({super.key, required this.profile});

  final DoctorPracticeProfile profile;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final rows = <(String, String)>[
      ('Medical degree', profile.medicalDegree ?? '—'),
      ('Registration no.', profile.registrationNumber ?? '—'),
      ('Speciality', profile.specialty ?? '—'),
      ('Phone', profile.phone ?? '—'),
    ];

    return ProfileSection(
      title: 'Verified details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileCard(
            children: [
              for (final (index, row) in rows.indexed)
                ProfileDetailRow(
                  label: tr(row.$1),
                  value: row.$2,
                  showDivider: index < rows.length - 1,
                ),
            ],
          ),
          SizedBox(height: sizing.spacingXs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_rounded,
                size: sizing.iconXs,
                color: AppColors.textTertiary,
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Text(
                  tr(
                    'These were checked against the certificate you uploaded, '
                    'so they are not editable here. Your phone number is your '
                    'sign-in. To correct any of them, contact support — the '
                    'change is reviewed before it takes effect.',
                  ),
                  style: sizing.text.legalBody,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
