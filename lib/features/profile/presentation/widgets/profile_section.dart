import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';

/// An all-caps heading above one of the profile's blocks.
///
/// Translates its own [title] and [actionLabel] at render, like the shared
/// widgets — callers pass the English.
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;

  /// An optional action on the section header, e.g. `Edit`. Shown only when
  /// [onAction] is also given.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final label = actionLabel;
    final action = onAction;

    final heading = Text(
      // Translated first, then upper-cased: the table is keyed by the English
      // as written, and upper-casing Devanagari is a no-op.
      tr(title).toUpperCase(),
      style: sizing.text.sectionTitle.copyWith(
        fontSize: sizing.sp(15),
        color: AppColors.textSecondary,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label == null || action == null)
          heading
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: heading),
              InkWell(
                onTap: action,
                borderRadius: BorderRadius.circular(sizing.radiusSm),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sizing.spacingXs,
                    vertical: sizing.spacingXxs,
                  ),
                  child: Text(tr(label), style: sizing.text.sectionAction),
                ),
              ),
            ],
          ),
        SizedBox(height: sizing.spacingXs + 2),
        child,
      ],
    );
  }
}

/// The white card the detail rows and the settings rows sit in.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.children, this.padded = true});

  final List<Widget> children;

  /// Inset for a card of text rows; false for one of full-width tap targets.
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padded
          ? EdgeInsets.symmetric(
              horizontal: sizing.cardPadding,
              vertical: sizing.spacingXs,
            )
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        boxShadow: AppShadows.card,
      ),
      child: Column(children: children),
    );
  }
}

/// A label on the left, its value on the right. Both are translated at render;
/// a value with no entry in the table (a name, an email) shows as it came.
class ProfileDetailRow extends StatelessWidget {
  const ProfileDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;

  /// False on the last row, where a rule would float above the card's edge.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: sizing.spacingSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(label),
                style: sizing.text.screenSubtitle.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: sizing.spacingSm),
              // The value takes the slack and wraps rather than overflowing —
              // a long email is the common case here.
              Expanded(
                child: Text(
                  tr(value),
                  textAlign: TextAlign.right,
                  style: sizing.text.fieldValue.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Container(height: sizing.hairline, color: AppColors.dividerFaint),
      ],
    );
  }
}

/// A tappable row into another screen. Translates its own [label], [subtitle]
/// and [value] at render.
class ProfileActionRow extends StatelessWidget {
  const ProfileActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// What the setting behind this row currently says, e.g. `Mon-Fri · 3 slots`.
  /// A row that leads to a setting should show its state; a row that leads to a
  /// screen has nothing to report and leaves this null.
  final String? subtitle;

  /// A short current value shown before the chevron, e.g. `₹500`. For anything
  /// longer than a few characters use [subtitle], which has the room.
  final String? value;

  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final subtitle = this.subtitle;
    final value = this.value;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sizing.cardPadding,
              vertical: sizing.spacingSm,
            ),
            child: Row(
              children: [
                Container(
                  width: sizing.iconChipSize * 0.75,
                  height: sizing.iconChipSize * 0.75,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(sizing.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    size: sizing.iconSm,
                    color: AppColors.primaryVivid,
                  ),
                ),
                SizedBox(width: sizing.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(label),
                        style: sizing.text.fieldValue.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: sizing.spacingXxs / 2),
                        Text(
                          tr(subtitle),
                          style: sizing.text.metaLabel.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (value != null) ...[
                  SizedBox(width: sizing.spacingXs),
                  // Bounded and ellipsised. A `Text` with no constraint in a
                  // `Row` overflows rather than shrinking, and this slot is
                  // fed from data — a fee, a count — so "a few characters" is
                  // a convention rather than a guarantee.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: sizing.w(96)),
                    child: Text(
                      tr(value),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sizing.text.fieldValue.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ),
                ],
                SizedBox(width: sizing.spacingXxs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: sizing.iconSm,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(left: sizing.cardPadding),
            child: Container(
              height: sizing.hairline,
              color: AppColors.dividerFaint,
            ),
          ),
      ],
    );
  }
}
