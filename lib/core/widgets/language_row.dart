import 'package:flutter/material.dart';

import '../../features/profile/presentation/widgets/profile_section.dart';
import '../di/service_locator.dart';
import '../l10n/language_controller.dart';
import '../l10n/tr.dart';
import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';

/// The profile row that picks the app's language. Shared by the patient and
/// the doctor profile.
class LanguageRow extends StatelessWidget {
  const LanguageRow({super.key, this.showDivider = true});

  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final controller = sl<LanguageController>();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ProfileActionRow(
        icon: Icons.translate_rounded,
        label: tr('Language'),
        value: controller.language.nativeName,
        showDivider: showDivider,
        onTap: () => LanguageSheet.show(context),
      ),
    );
  }
}

/// English or हिन्दी, applied the moment one is tapped.
class LanguageSheet extends StatelessWidget {
  const LanguageSheet({super.key});

  static Future<void> show(BuildContext context) {
    // Transparent, with the sheet painting its own surface — see
    // `AppearanceSheet` for why.
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => const LanguageSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final controller = sl<LanguageController>();

    return ListenableBuilder(
      listenable: controller,
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
                Text(tr('Language'), style: sizing.text.cardTitle),
                SizedBox(height: sizing.spacingXxs),
                Text(
                  tr('Choose the language the app speaks.'),
                  style: sizing.text.cardSubtitle,
                ),
                SizedBox(height: sizing.spacingMd),
                for (final language in AppLanguage.values) ...[
                  _LanguageOption(
                    language: language,
                    selected: controller.language == language,
                    onTap: () => controller.setLanguage(language),
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

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
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
                // The script itself, so the language is recognisable before
                // its name is read.
                Container(
                  width: sizing.r(38),
                  height: sizing.r(38),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : AppColors.surface,
                  ),
                  child: Text(
                    language == AppLanguage.hindi ? 'अ' : 'A',
                    style: sizing.text.cardTitle.copyWith(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: sizing.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.nativeName,
                        style: sizing.text.fieldValue.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.primaryDeep
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (language.nativeName != language.englishName)
                        Text(
                          language.englishName,
                          style: sizing.text.metaLabel,
                        ),
                    ],
                  ),
                ),
                if (language == AppLanguage.english)
                  Padding(
                    padding: EdgeInsets.only(right: sizing.spacingXs),
                    child: Text(
                      tr('Default'),
                      style: sizing.text.metaLabel.copyWith(
                        color: AppColors.textTertiary,
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
