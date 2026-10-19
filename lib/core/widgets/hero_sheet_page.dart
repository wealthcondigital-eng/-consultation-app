import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

/// Page shell for the entry screens: a brand-gradient hero with a white sheet
/// rising over it.
///
/// The split is doing work rather than decoration. Everything on the gradient
/// is the app introducing itself; everything on the white is what the user has
/// to do. Keeping that division identical from the splash through the role
/// choice to the login screen is what makes the launch read as one surface
/// being handed forward rather than three screens in a row.
///
/// The gradient is painted by the scaffold rather than by [hero], so it runs
/// under the status bar and, on a wide window, out to both edges while the
/// content column stays capped and centred.
class HeroSheetPage extends StatelessWidget {
  const HeroSheetPage({
    super.key,
    required this.hero,
    required this.sheet,
    this.expandHero = false,
  });

  /// The gradient half.
  final Widget hero;

  /// The white half. Normally a [HeroSheet].
  final Widget sheet;

  /// Which half absorbs the spare height.
  ///
  /// The sheet does by default — a form wants its foot on the bottom edge of
  /// the screen. Set true for a screen whose gradient is the point and whose
  /// sheet is a short row of actions, so the brand gets the room and the
  /// actions stay a thumb's reach from the bottom.
  final bool expandHero;

  /// Whether the sheet floats as a card rather than rising from the bottom
  /// edge.
  ///
  /// True exactly when the window is wider than the content column: a sheet is
  /// anchored to the bottom of the screen, and one capped at 480pt in the
  /// middle of a 1366pt window is anchored to nothing — it reads as a white
  /// stripe down the page. On a phone, where the column is the screen, the
  /// sheet is a sheet.
  static bool floatsAsCard(AppSizing sizing) =>
      sizing.screenSize.width > sizing.contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final floats = floatsAsCard(sizing);

    return Scaffold(
      // Seen behind the status bar during an overscroll, and behind the sheet's
      // rounded shoulders.
      backgroundColor: AppColors.primary,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.brandSweep),
        child: SafeArea(
          // The sheet pays the bottom inset itself, so its white reaches the
          // bottom edge of the screen instead of stopping above the gesture bar
          // with a band of teal beneath it.
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: sizing.contentMaxWidth),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    // Bounce rather than glow, and never scroll when it fits.
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          // A card is centred in the window with the hero above
                          // it; neither half stretches, because there is no
                          // edge for them to stretch to.
                          mainAxisAlignment: floats
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            if (!floats && expandHero)
                              Expanded(child: hero)
                            else
                              hero,
                            if (!floats && !expandHero)
                              Expanded(
                                child: _SheetSlot(
                                  isFlexible: true,
                                  child: sheet,
                                ),
                              )
                            else
                              _SheetSlot(isFlexible: false, child: sheet),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tells the sheet whether it was given the spare height.
///
/// A [Spacer] under an unbounded height throws, so whether the footer can be
/// pinned to the foot of the sheet is not the sheet's own business to guess —
/// it depends on which half of the page was made flexible, which only the page
/// knows. Absent (a [HeroSheet] used on its own), the answer is no.
class _SheetSlot extends InheritedWidget {
  const _SheetSlot({required this.isFlexible, required super.child});

  final bool isFlexible;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SheetSlot>()?.isFlexible ??
      false;

  @override
  bool updateShouldNotify(_SheetSlot oldWidget) =>
      oldWidget.isFlexible != isFlexible;
}

/// The white half of a [HeroSheetPage].
///
/// Owns the shape, the padding and the bottom inset so the two entry screens
/// cannot drift apart by a few points.
class HeroSheet extends StatelessWidget {
  const HeroSheet({super.key, required this.children, this.footer});

  /// The sheet's content, stretched to its width.
  final List<Widget> children;

  /// Kept at the foot of the sheet — the consent line, the trust line.
  ///
  /// Pinned to the bottom edge rather than left under [children]: it is the
  /// small print, and small print that floats halfway up a white panel reads
  /// as something the user was meant to act on.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final floats = HeroSheetPage.floatsAsCard(sizing);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: floats
            ? BorderRadius.circular(sizing.sheetRadius)
            : BorderRadius.vertical(top: Radius.circular(sizing.sheetRadius)),
        boxShadow: floats ? AppShadows.card : null,
      ),
      padding: EdgeInsets.only(
        top: sizing.spacingXl,
        left: sizing.screenPaddingH,
        right: sizing.screenPaddingH,
        // The page's SafeArea stops above the sheet, so the gesture bar's inset
        // is paid here — once, and by the surface that covers it. A floating
        // card does not reach the bottom edge and owes nothing.
        bottom: floats
            ? sizing.screenPaddingV
            : sizing.screenPaddingV + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...children,
          if (footer case final footer?) ...[
            SizedBox(height: sizing.spacingXxl),
            // Collapses to nothing on a short screen, and to nothing again when
            // the keyboard is up — which is what keeps a form's field and its
            // button on screen together rather than pushing the button below
            // the fold. A sheet that was not given the spare height sizes to
            // its contents instead, and leaves the footer directly under them.
            if (_SheetSlot.of(context)) const Spacer(),
            footer,
          ],
        ],
      ),
    );
  }
}
