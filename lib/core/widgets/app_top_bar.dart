import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

enum AppTopBarVariant {
  /// Muted grey circle — used on the onboarding and auth screens.
  filled,

  /// Larger white circle with a hairline border — used on cards-on-canvas
  /// screens where a grey fill would disappear into the background.
  outlined,

  /// Translucent white circle and a white title — for a bar sitting on the
  /// brand gradient, where the dark title and grey fill would both vanish.
  onBrand,
}

/// Screen header: a round back affordance followed by the screen title.
///
/// Used in place of [AppBar] so the height, the button and the title style all
/// come from the design tokens.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.variant = AppTopBarVariant.filled,
    this.centerTitle = false,
    this.trailing,
  });

  final String title;
  final AppTopBarVariant variant;

  /// Optional control at the far end of the bar, e.g. a privacy badge.
  final Widget? trailing;

  /// Centres the title, balancing the back button with an equal gap on the
  /// right so the text sits on the screen's axis.
  final bool centerTitle;

  /// Override for the back action. When null the bar pops the route, and
  /// hides the control entirely on a root screen that cannot pop.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final canPop = Navigator.of(context).canPop();
    final showsBack = onBack != null || canPop;
    final buttonSize = _backButtonSize(sizing, variant);

    return SizedBox(
      height: sizing.topBarHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: sizing.screenPaddingH),
        child: Row(
          children: [
            if (showsBack) ...[
              _BackButton(
                variant: variant,
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              SizedBox(
                width: variant == AppTopBarVariant.outlined
                    ? sizing.spacingMd
                    : sizing.spacingSm,
              ),
            ],
            Expanded(
              child: Text(
                tr(title),
                textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                style: variant == AppTopBarVariant.onBrand
                    ? sizing.text.navTitle.copyWith(color: AppColors.onBrand)
                    : sizing.text.navTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Mirrors the back button so a centred title lands on the axis.
            // A trailing control does that job on its own.
            if (trailing case final trailing?)
              trailing
            else if (centerTitle && showsBack)
              SizedBox(width: buttonSize),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed, required this.variant});

  final VoidCallback onPressed;
  final AppTopBarVariant variant;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final size = _backButtonSize(sizing, variant);

    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: switch (variant) {
              AppTopBarVariant.filled => AppColors.surfaceMuted,
              AppTopBarVariant.outlined => AppColors.surface,
              AppTopBarVariant.onBrand => AppColors.onBrandSurface,
            },
            shape: BoxShape.circle,
            border: switch (variant) {
              AppTopBarVariant.outlined => Border.all(
                width: sizing.hairline,
                color: AppColors.border,
              ),
              AppTopBarVariant.onBrand => Border.all(
                width: sizing.hairline,
                color: AppColors.onBrandBorder,
              ),
              AppTopBarVariant.filled => null,
            },
          ),
          child: Icon(
            Icons.arrow_back,
            size: variant == AppTopBarVariant.outlined
                ? sizing.iconLg
                : sizing.iconXs,
            color: variant == AppTopBarVariant.onBrand
                ? AppColors.onBrand
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// The circle's diameter. Only the outlined variant is larger — it sits on a
/// tinted page where a 32pt control reads as an afterthought.
double _backButtonSize(AppSizing sizing, AppTopBarVariant variant) =>
    variant == AppTopBarVariant.outlined
    ? sizing.avatarSize
    : sizing.iconButtonSize;
