import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';

/// Page shell shared by every screen.
///
/// It does three things that would otherwise be repeated everywhere:
///  * caps the content column on tablets and centres it, so a phone layout is
///    never stretched across a 1024pt window;
///  * guarantees the content is at least as tall as the viewport while still
///    scrolling when it is taller — so `Spacer`/`spaceBetween` layouts survive
///    short screens and the on-screen keyboard;
///  * keeps clear of notches and system bars via [SafeArea].
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.backgroundColor,
    this.scrollable = true,
  });

  final Widget child;

  /// Defaults to [AppColors.surface].
  final Color? backgroundColor;

  /// Set false for screens that manage their own scrolling (e.g. a ListView).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: sizing.contentMaxWidth),
            child: scrollable ? _Scrollable(child: child) : child,
          ),
        ),
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          // Bounce rather than glow, and never scroll when it already fits.
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}
