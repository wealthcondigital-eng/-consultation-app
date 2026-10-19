import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// One destination on the bar.
///
/// Two icons: an outline at rest and a filled one when selected. Weight rather
/// than colour alone is what makes the current tab readable at a glance, and
/// for anyone who cannot separate two hues it is the only signal that works.
@immutable
class AppNavDestination {
  const AppNavDestination({
    required this.label,
    required this.icon,
    IconData? activeIcon,
  }) : activeIcon = activeIcon ?? icon;

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// The app's bottom navigation: a floating bar whose selected destination
/// expands into a brand-gradient pill carrying its own label.
///
/// Why this shape rather than the stock [BottomNavigationBar]:
///
///  * **The label is only where it is needed.** At rest every tab is an icon;
///    the selected one grows a label beside it. That removes four permanent
///    captions from the bottom of every screen and leaves the one that answers
///    "where am I" — and it is why a four-tab bar no longer has to shrink
///    "Appointments" down to fit a quarter of a 320pt phone.
///  * **The selection is one object moving.** The pill grows in place while the
///    others contract, so the movement reads as one thing travelling to where
///    you tapped instead of four things changing colour at once.
///  * **It floats.** Inset from the edges with a shadow under it, so the bar
///    sits above the page rather than being fenced off from it by a rule — and
///    the page background runs to the bottom of the screen behind it.
///
/// Generic over the tab type so both roles drive the same widget. The two bars
/// used to be separate files that had drifted apart: one animated and
/// pill-backed, the other a static row with a top border, so moving between the
/// patient app and the doctor app felt like moving between two apps.
class AppBottomNavBar<T> extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.destinations,
    required this.current,
    required this.onSelected,
  });

  /// In bar order. Iteration order is draw order, which every Dart map literal
  /// preserves.
  final Map<T, AppNavDestination> destinations;

  final T current;
  final ValueChanged<T> onSelected;

  static const Duration duration = Duration(milliseconds: 340);
  static const Curve curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final entries = destinations.entries.toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          sizing.spacingSm,
          sizing.spacingXs,
          sizing.spacingSm,
          sizing.spacingXs,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: sizing.spacingXs,
            vertical: sizing.spacingXs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(sizing.radiusPill),
            border: Border.all(width: sizing.hairline, color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0C2B2D),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          // Widths are computed rather than flexed.
          //
          // Flex cannot express what this bar does: the selected item needs
          // roughly twice the room of the others, and `Flexible` hands every
          // child an equal share — so on a 320pt phone with four tabs the
          // selected pill was given a quarter of the bar, its icon and label
          // did not fit, and the row overflowed. Sharing the width out
          // explicitly also means `AnimatedContainer` has a number to animate
          // between, which is what makes the pill grow rather than snap.
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The selected item counts double, so the shares always add up
              // to exactly one whatever the tab count.
              final units = entries.length + 1;
              final unit = constraints.maxWidth / units;

              return Row(
                children: [
                  for (final entry in entries)
                    _NavItem(
                      destination: entry.value,
                      isSelected: entry.key == current,
                      width: entry.key == current ? unit * 2 : unit,
                      onTap: () => onSelected(entry.key),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.width,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool isSelected;

  /// This item's share of the bar, worked out by [AppBottomNavBar]. Animated
  /// between, so the pill grows and the others give way in one movement.
  final double width;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      button: true,
      selected: isSelected,
      label: tr(destination.label),
      // The icon and the label are one control, and the label is only drawn on
      // the selected tab — so without this a screen reader announced the
      // destination twice on the tab you were already on and once elsewhere.
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppBottomNavBar.duration,
        curve: AppBottomNavBar.curve,
        width: width,
        height: sizing.h(46),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.brandBar : null,
          borderRadius: BorderRadius.circular(sizing.radiusPill),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        // Clipped to the pill, so a label mid-animation cannot paint outside
        // the rounded edge it is sliding out of.
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            // A tap that only slides a pill can feel unregistered on a slow
            // frame; the tick confirms it landed.
            HapticFeedback.selectionClick();
            onTap();
          },
          // No ripple: the pill already answers the tap, and a splash on top of
          // a gradient reads as two things happening at once.
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? destination.activeIcon : destination.icon,
                size: sizing.iconMd,
                color: isSelected ? Colors.white : AppColors.textTertiary,
              ),
              // Revealed by a width factor rather than added and removed, so
              // the label slides out from behind the icon instead of appearing
              // on top of it. Flexible around it because the pill's width is
              // decided by the bar, not by how long this word happens to be —
              // "Appointments" on a 320pt phone has to give way rather than
              // overflow.
              Flexible(
                child: AnimatedAlign(
                  duration: AppBottomNavBar.duration,
                  curve: AppBottomNavBar.curve,
                  alignment: Alignment.centerLeft,
                  widthFactor: isSelected ? 1 : 0,
                  child: AnimatedOpacity(
                    duration: AppBottomNavBar.duration,
                    curve: AppBottomNavBar.curve,
                    opacity: isSelected ? 1 : 0,
                    child: Padding(
                      padding: EdgeInsets.only(left: sizing.spacingXs),
                      child: Text(
                        tr(destination.label),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: sizing.text.navLabel.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: sizing.sp(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
