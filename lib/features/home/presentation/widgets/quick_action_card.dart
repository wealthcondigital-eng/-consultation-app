import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/l10n/tr.dart';

/// A large tinted call-to-action card: icon badge, title, one line of copy.
class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final AccentPalette accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusLg);

    return Material(
      color: accent.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(sizing.cardPadding),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(width: sizing.hairline, color: accent.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: sizing.avatarSize,
                height: sizing.avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.icon,
                  borderRadius: BorderRadius.circular(sizing.radiusMd),
                ),
                child: Icon(icon, size: sizing.iconSm, color: Colors.white),
              ),
              SizedBox(height: sizing.spacingSm),
              Text(
                tr(title),
                style: sizing.text.cardTitle.copyWith(color: accent.onSurface),
              ),
              SizedBox(height: sizing.spacingXxs),
              Text(
                tr(subtitle),
                style: sizing.text.cardSubtitle.copyWith(
                  // Softened against the tinted background rather than given a
                  // separate colour token.
                  color: accent.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
