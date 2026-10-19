import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_field_shell.dart';
import '../../domain/entities/consult_language.dart';

/// "Preferred Language" — a field that opens [ConsultLanguageSheet].
class ConsultLanguageField extends StatelessWidget {
  const ConsultLanguageField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ConsultLanguage value;
  final ValueChanged<ConsultLanguage> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await ConsultLanguageSheet.show(context, selected: value);
    if (picked != null && picked != value) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      button: true,
      label: '${tr('Preferred Language')}: ${value.nativeName}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: AppFieldShell(
          label: 'Preferred Language',
          leading: Icon(
            Icons.translate_rounded,
            size: sizing.iconXs,
            color: AppColors.textSecondary,
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: sizing.iconSm,
            color: AppColors.textSecondary,
          ),
          child: Row(
            children: [
              Text(value.nativeName, style: sizing.text.fieldValue),
              if (value.nativeName != value.label) ...[
                SizedBox(width: sizing.spacingXs),
                Text(
                  '· ${tr(value.label)}',
                  style: sizing.text.fieldPlaceholder,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The languages the on-call panel consults in, as a grid of tiles — each in
/// its own script first, so a patient finds theirs at a glance.
class ConsultLanguageSheet extends StatelessWidget {
  const ConsultLanguageSheet({super.key, required this.selected});

  final ConsultLanguage selected;

  static Future<ConsultLanguage?> show(
    BuildContext context, {
    required ConsultLanguage selected,
  }) {
    return showModalBottomSheet<ConsultLanguage>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (_) => ConsultLanguageSheet(selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
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
            sizing.spacingSm,
            sizing.screenPaddingH,
            sizing.spacingMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: sizing.r(36),
                  height: sizing.r(4),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(sizing.radiusPill),
                  ),
                ),
              ),
              SizedBox(height: sizing.spacingMd),
              Row(
                children: [
                  Container(
                    width: sizing.r(40),
                    height: sizing.r(40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.anonymousAccent.surface,
                      borderRadius: BorderRadius.circular(sizing.radiusMd),
                    ),
                    child: Icon(
                      Icons.record_voice_over_rounded,
                      size: sizing.iconMd,
                      color: AppColors.anonymousAccent.icon,
                    ),
                  ),
                  SizedBox(width: sizing.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Preferred Language'),
                          style: sizing.text.cardTitle.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          tr('We’ll connect you with a doctor who speaks it.'),
                          style: sizing.text.cardSubtitle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: sizing.spacingMd),
              LayoutBuilder(
                builder: (context, constraints) {
                  final gap = sizing.spacingSm;
                  final width = (constraints.maxWidth - gap) / 2;

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final language in ConsultLanguage.values)
                        SizedBox(
                          width: width,
                          child: _LanguageTile(
                            language: language,
                            selected: language == selected,
                            onTap: () => Navigator.of(context).pop(language),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final ConsultLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final accent = AppColors.anonymousAccent;
    final radius = BorderRadius.circular(sizing.radiusMd);

    return Semantics(
      button: true,
      selected: selected,
      label: '${language.nativeName}, ${language.label}',
      excludeSemantics: true,
      child: Material(
        color: selected ? accent.surface : AppColors.surfaceMuted,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: EdgeInsets.all(sizing.spacingSm),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                width: selected ? sizing.r(1.5) : sizing.hairline,
                color: selected ? accent.icon : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: sizing.r(36),
                  height: sizing.r(36),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? accent.icon : AppColors.surface,
                  ),
                  child: Text(
                    language.glyph,
                    style: sizing.text.cardTitle.copyWith(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: sizing.spacingXs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.nativeName,
                        style: sizing.text.fieldValue.copyWith(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? accent.onSurface
                              : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        tr(language.label),
                        style: sizing.text.metaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: sizing.iconSm,
                    color: accent.icon,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
