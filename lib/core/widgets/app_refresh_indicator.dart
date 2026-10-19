import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pull-to-refresh, in the app's colours.
///
/// A wrapper rather than a theme entry, because there is no theming to be had:
/// `RefreshIndicator` builds its spinner with `widget.color ?? colorScheme
/// .primary` and passes that straight down as a `valueColor`, so
/// `ProgressIndicatorThemeData.color` never reaches it. The scheme's primary is
/// a tone Material derived from the brand seed, not the brand teal — close
/// enough to look deliberate and wrong enough to notice next to a teal button.
///
/// Every list in the app pulls through here, so the colour is set in one place
/// and a list added next month inherits it by using this instead of the
/// framework's.
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.edgeOffset = 0,
  });

  /// Runs on pull. The indicator stays up until it completes.
  final Future<void> Function() onRefresh;

  final Widget child;

  /// How far down the spinner starts, for a list sitting under a header that
  /// is not part of the scroll view.
  final double edgeOffset;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      edgeOffset: edgeOffset,
      // The deep teal, not `primary`: the spinner is drawn on a raised white
      // disc at about twenty logical pixels, and the lighter teal reads as grey
      // at that size.
      color: AppColors.primaryDeep,
      backgroundColor: AppColors.surface,
      // Material's default is 2.0, which on the brand's thinner iconography
      // looks like a different family of shape.
      strokeWidth: 2.5,
      child: child,
    );
  }
}
