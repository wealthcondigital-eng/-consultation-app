import 'package:flutter/material.dart';

import '../../features/profile/presentation/widgets/profile_section.dart';
import '../di/service_locator.dart';
import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import '../l10n/tr.dart';

/// The profile row that picks light, dark or the phone's own setting.
///
/// Shared by the patient and the doctor profile — the theme is a property of
/// the device, not of either role.
class AppearanceRow extends StatelessWidget {
  const AppearanceRow({super.key, this.showDivider = true});

  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = sl<ThemeController>();

    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => ProfileActionRow(
        icon: Icons.contrast_rounded,
        label: tr('Appearance'),
        value: tr(theme.mode.label),
        showDivider: showDivider,
        onTap: () => AppearanceSheet.show(context),
      ),
    );
  }
}

/// System default, Light, Dark — applied the moment one is tapped, so the
/// sheet itself previews the choice.
class AppearanceSheet extends StatelessWidget {
  const AppearanceSheet({super.key});

  static Future<void> show(BuildContext context) {
    // Transparent, with the sheet painting its own surface: a colour passed
    // here is fixed when the sheet opens, and this is the one sheet whose
    // whole job is to change that colour while it is open.
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => const AppearanceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final theme = sl<ThemeController>();

    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(sizing.radiusXl),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              sizing.screenPaddingH,
              0,
              sizing.screenPaddingH,
              sizing.spacingMd,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: sizing.spacingSm),
                    width: sizing.r(36),
                    height: sizing.r(4),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(sizing.radiusPill),
                    ),
                  ),
                ),
                Text(tr('Appearance'), style: sizing.text.cardTitle),
                SizedBox(height: sizing.spacingXxs),
                Text(
                  tr('System default follows your phone’s dark mode setting.'),
                  style: sizing.text.cardSubtitle,
                ),
                SizedBox(height: sizing.spacingMd),
                for (final mode in ThemeMode.values) ...[
                  _ModeOption(
                    mode: mode,
                    selected: theme.mode == mode,
                    onTap: () => theme.setMode(mode),
                  ),
                  SizedBox(height: sizing.spacingXs),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusMd);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primarySurface : AppColors.surfaceMuted,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: sizing.spacingMd,
              vertical: sizing.spacingSm,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                width: selected ? sizing.r(1.5) : sizing.hairline,
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  mode.icon,
                  size: sizing.iconMd,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                SizedBox(width: sizing.spacingSm),
                Expanded(
                  child: Text(
                    tr(mode.label),
                    style: sizing.text.fieldValue.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.primaryDeep
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: sizing.iconMd,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
