import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../home/domain/entities/patient_dashboard.dart';

/// What the app adds up to for this patient: consultations, doctors seen, and
/// what it has cost.
///
/// These three used to sit at the top of the dashboard, above Consult Now.
/// They are a *record* — nothing on them is actionable, and a running total of
/// money spent is the last thing somebody opening a health app to talk to a
/// doctor needs in their way. Here they are where a person goes to look
/// themselves up, which is when the question they answer is actually being
/// asked.
///
/// The completeness nudge came with them, for the same reason and one more: the
/// thing it asks for — a filled-in medical record — is edited on this screen,
/// so the prompt and the fix are now one tap apart instead of a tab apart.
class PatientStatsCard extends StatelessWidget {
  const PatientStatsCard({
    super.key,
    required this.dashboard,
    required this.onCompleteProfile,
  });

  final PatientDashboard dashboard;

  /// Opens the details form. Shown only while
  /// [PatientDashboard.shouldPromptProfile].
  final VoidCallback onCompleteProfile;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sizing.cardPadding,
              vertical: sizing.spacingMd,
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _Metric(
                      icon: Icons.medical_services_rounded,
                      label: 'Consults',
                      value: '${dashboard.consultations}',
                      color: AppColors.primary,
                    ),
                  ),
                  const _MetricDivider(),
                  Expanded(
                    child: _Metric(
                      icon: Icons.group_rounded,
                      label: 'Doctors',
                      value: '${dashboard.doctorsSeen}',
                      color: AppColors.success,
                    ),
                  ),
                  const _MetricDivider(),
                  Expanded(
                    child: _Metric(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Spent',
                      value: dashboard.spendLabel,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (dashboard.shouldPromptProfile)
            _CompletenessStrip(
              completeness: dashboard.completeness,
              percent: dashboard.profileCompleteness,
              onTap: onCompleteProfile,
            ),
        ],
      ),
    );
  }
}

/// The nudge, and it is deliberately a strip rather than a dialog.
///
/// A medical record a doctor can read is worth more than one they cannot, so
/// asking is right; interrupting somebody is not.
class _CompletenessStrip extends StatelessWidget {
  const _CompletenessStrip({
    required this.completeness,
    required this.percent,
    required this.onTap,
  });

  final double completeness;
  final int percent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.primarySurface,
        padding: EdgeInsets.symmetric(
          horizontal: sizing.cardPadding,
          vertical: sizing.spacingSm,
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: sizing.iconMd,
              child: CircularProgressIndicator(
                value: completeness,
                strokeWidth: sizing.r(3),
                backgroundColor: AppColors.surface,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            SizedBox(width: sizing.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Profile {percent}% complete', {'percent': percent}),
                    style: sizing.text.cardTitle.copyWith(
                      color: AppColors.primaryDeep,
                    ),
                  ),
                  SizedBox(height: sizing.spacingXxs / 2),
                  Text(
                    tr('Add your details so a doctor can see them on a call.'),
                    style: sizing.text.metaLabel.copyWith(
                      color: AppColors.primaryDeep,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: sizing.iconSm,
              color: AppColors.primaryDeep,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      children: [
        Icon(icon, size: sizing.iconSm, color: color),
        SizedBox(height: sizing.spacingXxs),
        Text(
          value,
          style: sizing.text.amountTotal.copyWith(
            fontSize: sizing.sp(18),
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: sizing.spacingXxs / 2),
        Text(
          tr(label),
          style: sizing.text.metaLabel.copyWith(color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: sizing.hairline,
      margin: EdgeInsets.symmetric(vertical: sizing.spacingXxs),
      color: AppColors.dividerFaint,
    );
  }
}
