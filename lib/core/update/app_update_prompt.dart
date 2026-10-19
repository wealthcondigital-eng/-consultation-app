import 'package:flutter/material.dart';

import '../di/service_locator.dart';
import '../l10n/tr.dart';
import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import 'app_update_controller.dart';

/// Asks Play for an update once per launch and, if there is one, raises
/// [AppUpdateSheet]. Draws nothing itself; sits on both home screens.
class AppUpdatePrompter extends StatefulWidget {
  const AppUpdatePrompter({super.key});

  @override
  State<AppUpdatePrompter> createState() => _AppUpdatePrompterState();
}

class _AppUpdatePrompterState extends State<AppUpdatePrompter> {
  late final AppUpdateController _controller = sl<AppUpdateController>();

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onChanged)
      ..check();
    // An update found before this screen existed (a second home screen, a
    // return from elsewhere) still gets its one sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChanged());
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;

    if (_controller.phase == AppUpdatePhase.available &&
        _controller.claimPrompt()) {
      // After the frame: a sheet cannot be pushed mid-build. And ask for that
      // frame — the update check finishes in the background, and a screen
      // nobody is touching would otherwise not draw one, leaving the sheet
      // queued until the next scroll or tap.
      WidgetsBinding.instance
        ..addPostFrameCallback((_) {
          if (mounted) AppUpdateSheet.show(context);
        })
        ..ensureVisualUpdate();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// "A new version is ready" — the once-per-launch offer.
///
/// Stays open through the download so the bar can be watched to 100%. Later
/// hands the offer to the profile's [AppUpdateCard]. A required update has no
/// Later and cannot be swiped away.
class AppUpdateSheet extends StatelessWidget {
  const AppUpdateSheet({super.key});

  static Future<void> show(BuildContext context) {
    final controller = sl<AppUpdateController>();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      isDismissible: !controller.isRequired,
      enableDrag: !controller.isRequired,
      builder: (_) => const AppUpdateSheet(),
    ).then((_) {
      // Closed without starting: that is a Later too.
      if (controller.phase == AppUpdatePhase.available) controller.dismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final controller = sl<AppUpdateController>();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final phase = controller.phase;
        final busy = _isBusy(phase);

        // The update finished or vanished under the sheet: nothing to show.
        if (phase == AppUpdatePhase.none) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
        }

        return PopScope(
          canPop: !controller.isRequired,
          child: Container(
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
                          borderRadius: BorderRadius.circular(
                            sizing.radiusPill,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: sizing.spacingLg),
                    _Hero(phase: phase),
                    SizedBox(height: sizing.spacingMd),
                    Text(
                      _title(controller),
                      textAlign: TextAlign.center,
                      style: sizing.text.screenTitleCompact,
                    ),
                    SizedBox(height: sizing.spacingXs),
                    Text(
                      _subtitle(controller),
                      textAlign: TextAlign.center,
                      style: sizing.text.cardSubtitle.copyWith(height: 1.4),
                    ),
                    SizedBox(height: sizing.spacingLg),
                    if (busy)
                      UpdateProgressBar(controller: controller)
                    else ...[
                      for (final point in [
                        (Icons.bolt_rounded, tr('Faster and smoother')),
                        (
                          Icons.verified_user_rounded,
                          tr('Latest security fixes'),
                        ),
                        (Icons.auto_awesome_rounded, tr('New improvements')),
                      ]) ...[
                        _Point(icon: point.$1, label: point.$2),
                        SizedBox(height: sizing.spacingXs),
                      ],
                      SizedBox(height: sizing.spacingMd),
                      _PrimaryButton(
                        label: phase == AppUpdatePhase.failed
                            ? tr('Try again')
                            : tr('Update now'),
                        onTap: controller.start,
                      ),
                      if (!controller.isRequired) ...[
                        SizedBox(height: sizing.spacingXs),
                        TextButton(
                          onPressed: () {
                            controller.dismiss();
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            tr('Later'),
                            style: sizing.text.sectionAction.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _title(AppUpdateController controller) =>
      switch (controller.phase) {
        AppUpdatePhase.starting => tr('Getting the update ready'),
        AppUpdatePhase.downloading => tr('Updating the app'),
        AppUpdatePhase.installing => tr('Update ready'),
        AppUpdatePhase.failed => tr('Update didn’t finish'),
        _ =>
          controller.isRequired
              ? tr('Important update')
              : tr('A new version is ready'),
      };

  static String _subtitle(AppUpdateController controller) =>
      switch (controller.phase) {
        AppUpdatePhase.starting || AppUpdatePhase.downloading => tr(
          'You can keep using the app. We’ll restart it when it’s done.',
        ),
        AppUpdatePhase.installing => tr('Restarting the app…'),
        AppUpdatePhase.failed => tr('Check your connection and try again.'),
        _ =>
          controller.isRequired
              ? tr('Please update to keep consulting without interruptions.')
              : tr('Update now for the best consultation experience.'),
      };
}

/// The offer, kept on the profile after Later — with the same progress bar
/// once it is taken.
class AppUpdateCard extends StatelessWidget {
  const AppUpdateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final controller = sl<AppUpdateController>();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isVisible) return const SizedBox.shrink();

        final phase = controller.phase;
        final busy = _isBusy(phase);

        return Container(
          padding: EdgeInsets.all(sizing.cardPadding),
          decoration: BoxDecoration(
            gradient: AppColors.brandSweep,
            borderRadius: BorderRadius.circular(sizing.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: sizing.r(40),
                    height: sizing.r(40),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.onBrandSurface,
                    ),
                    child: Icon(
                      Icons.system_update_rounded,
                      size: sizing.iconMd,
                      color: AppColors.onBrand,
                    ),
                  ),
                  SizedBox(width: sizing.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppUpdateSheet._title(controller),
                          style: sizing.text.cardTitle.copyWith(
                            color: AppColors.onBrand,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          busy
                              ? AppUpdateSheet._subtitle(controller)
                              : tr('A newer version of the app is available.'),
                          style: sizing.text.metaLabel.copyWith(
                            color: AppColors.onBrandMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!busy) ...[
                    SizedBox(width: sizing.spacingXs),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(sizing.radiusPill),
                      child: InkWell(
                        onTap: controller.start,
                        borderRadius: BorderRadius.circular(sizing.radiusPill),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: sizing.spacingSm,
                            vertical: sizing.spacingXxs + 2,
                          ),
                          child: Text(
                            phase == AppUpdatePhase.failed
                                ? tr('Retry')
                                : tr('Update'),
                            style: sizing.text.badgeLabel.copyWith(
                              color: const Color(0xFF12565A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (busy) ...[
                SizedBox(height: sizing.spacingSm),
                UpdateProgressBar(controller: controller, onBrand: true),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A bar that fills to 100%, with the percentage beside it.
class UpdateProgressBar extends StatelessWidget {
  const UpdateProgressBar({
    super.key,
    required this.controller,
    this.onBrand = false,
  });

  final AppUpdateController controller;

  /// On the teal card rather than a plain surface.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final starting = controller.phase == AppUpdatePhase.starting;
    final value = starting ? null : controller.progress;
    final track = onBrand ? AppColors.onBrandSurface : AppColors.surfaceMuted;
    final fill = onBrand ? AppColors.onBrand : AppColors.primary;
    final label = onBrand ? AppColors.onBrand : AppColors.textPrimary;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(sizing.radiusPill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value ?? 0),
              duration: const Duration(milliseconds: 300),
              builder: (context, animated, _) => LinearProgressIndicator(
                value: value == null ? null : animated,
                minHeight: sizing.r(10),
                backgroundColor: track,
                valueColor: AlwaysStoppedAnimation(fill),
              ),
            ),
          ),
        ),
        SizedBox(width: sizing.spacingSm),
        SizedBox(
          width: sizing.r(44),
          child: Text(
            starting ? '…' : '${(controller.progress * 100).round()}%',
            textAlign: TextAlign.end,
            style: sizing.text.cardTitle.copyWith(
              color: label,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

bool _isBusy(AppUpdatePhase phase) =>
    phase == AppUpdatePhase.starting ||
    phase == AppUpdatePhase.downloading ||
    phase == AppUpdatePhase.installing;

class _Hero extends StatelessWidget {
  const _Hero({required this.phase});

  final AppUpdatePhase phase;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final size = sizing.r(84);

    return Center(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.brandSweep,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: sizing.r(20),
              spreadRadius: sizing.r(2),
            ),
          ],
        ),
        child: Icon(
          switch (phase) {
            AppUpdatePhase.installing => Icons.restart_alt_rounded,
            AppUpdatePhase.failed => Icons.refresh_rounded,
            AppUpdatePhase.starting ||
            AppUpdatePhase.downloading => Icons.downloading_rounded,
            _ => Icons.rocket_launch_rounded,
          },
          size: size * 0.46,
          color: AppColors.onBrand,
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      children: [
        Container(
          width: sizing.r(28),
          height: sizing.r(28),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(sizing.radiusSm),
          ),
          child: Icon(icon, size: sizing.iconXs, color: AppColors.primary),
        ),
        SizedBox(width: sizing.spacingSm),
        Expanded(child: Text(label, style: sizing.text.bodySmall)),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return SizedBox(
      height: sizing.buttonHeight,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sizing.radiusMd),
          ),
        ),
        child: Text(
          label,
          style: sizing.text.buttonLabel.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
