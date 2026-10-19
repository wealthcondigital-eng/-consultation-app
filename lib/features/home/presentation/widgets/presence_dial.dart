import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/l10n/tr.dart';

/// The big round switch the doctor's whole day hangs on: tap to go online, tap
/// again to stop taking consultations.
///
/// Neumorphic: a soft plate raised out of the page, a recessed track, and the
/// button itself sitting in it. The button sinks under the finger and springs
/// back, so it reads as something to press rather than a badge that happens to
/// be round. Going online, a halo breathes out from it three times — the one
/// moving thing on the screen, and it means "patients can reach you".
///
/// Deliberately the largest thing on the screen — it is the one control a
/// doctor reaches for between patients.
class PresenceDial extends StatefulWidget {
  const PresenceDial({
    super.key,
    required this.isOnline,
    required this.isBusy,
    required this.onTap,
  });

  final bool isOnline;

  /// True while the change is being saved.
  final bool isBusy;

  final VoidCallback onTap;

  @override
  State<PresenceDial> createState() => _PresenceDialState();
}

class _PresenceDialState extends State<PresenceDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  bool _pressed = false;

  static const Duration _press = Duration(milliseconds: 140);

  // The plate's two lights. The page is [AppColors.canvas]; the highlight is
  // brighter than it and the shade a tint of the brand ink, which is what
  // makes the plate look lifted out of the same material rather than stuck on.
  static const Color _highlight = Color(0xFFFFFFFF);
  static const Color _shade = Color(0x2E0C2B2D);

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(PresenceDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnline != widget.isOnline ||
        oldWidget.isBusy != widget.isBusy) {
      _syncPulse();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Breathes only when online and settled — a halo during a save would be
  /// promising a state the server has not confirmed yet.
  void _syncPulse() {
    if (widget.isOnline && !widget.isBusy) {
      // Three breaths, then still. A halo that never stops is noise the
      // doctor learns to ignore, and it never lets the screen settle.
      if (!_pulse.isAnimating) _pulse.repeat(count: 3);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final isOnline = widget.isOnline;
    final enabled = !widget.isBusy;

    final plate = sizing.r(184);
    final track = plate * 0.84;
    final button = plate * 0.70;

    final colors = isOnline
        ? const [Color(0xFF34D27A), Color(0xFF16A34A), Color(0xFF12803B)]
        : const [Color(0xFFA7B4C2), Color(0xFF74859A), Color(0xFF56667A)];
    final glow = isOnline ? const Color(0x5516A34A) : const Color(0x40334155);

    return Semantics(
      button: true,
      toggled: isOnline,
      enabled: enabled,
      label: isOnline
          ? tr('You are online. Tap to stop taking consultations.')
          : tr('You are offline. Tap to start taking consultations.'),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: enabled ? _handleTap : null,
        child: SizedBox.square(
          dimension: plate,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The raised plate.
              Container(
                width: plate,
                height: plate,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.canvas,
                  boxShadow: [
                    BoxShadow(
                      color: _highlight,
                      blurRadius: 24,
                      offset: Offset(-10, -10),
                    ),
                    BoxShadow(
                      color: _shade,
                      blurRadius: 24,
                      offset: Offset(10, 10),
                    ),
                  ],
                ),
              ),
              // The recessed track. Dark where the plate's light cannot reach
              // (top left, under the rim) and light at the bottom right —
              // the reverse of the plate, which is what reads as a dip.
              Container(
                width: track,
                height: track,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.isDark
                        ? [AppColors.surfaceMuted, AppColors.surface]
                        : const [Color(0xFFDDE5E6), Color(0xFFFDFEFE)],
                  ),
                ),
              ),
              // The halo, breathing out from under the button.
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(_pulse.value);
                  if (t == 0) return const SizedBox.shrink();

                  final size = button + (track - button) * t;
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: sizing.r(2),
                        color: colors[1].withValues(alpha: 0.55 * (1 - t)),
                      ),
                    ),
                  );
                },
              ),
              // The button.
              AnimatedScale(
                scale: _pressed ? 0.94 : 1,
                duration: _press,
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: _press,
                  curve: Curves.easeOut,
                  width: button,
                  height: button,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                    border: Border.all(
                      width: sizing.r(1.5),
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    // Pressed, the shadows pull in: the button has gone down
                    // into the track and no longer throws one.
                    boxShadow: _pressed
                        ? [
                            BoxShadow(
                              color: glow,
                              blurRadius: 6,
                              offset: const Offset(2, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: glow,
                              blurRadius: 18,
                              offset: const Offset(6, 8),
                            ),
                            const BoxShadow(
                              color: Color(0xB3FFFFFF),
                              blurRadius: 10,
                              offset: Offset(-4, -4),
                            ),
                          ],
                  ),
                  child: widget.isBusy
                      ? SizedBox.square(
                          dimension: sizing.iconMd,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.power_settings_new_rounded,
                              size: sizing.iconMd,
                              color: Colors.white,
                            ),
                            SizedBox(height: sizing.spacingXxs),
                            Text(
                              isOnline ? tr('Online') : tr('Offline'),
                              style: sizing.text.headline.copyWith(
                                fontSize: sizing.sp(18),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: sizing.spacingXxs * 0.5),
                            Text(
                              isOnline
                                  ? tr('Tap to go offline')
                                  : tr('Tap to go online'),
                              style: sizing.text.metaLabel.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

/// The line under the dial explaining what the current state means.
class PresenceNote extends StatelessWidget {
  const PresenceNote({super.key, required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: sizing.r(8),
          height: sizing.r(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? AppColors.successStrong : AppColors.textTertiary,
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        Flexible(
          child: Text(
            isOnline
                ? tr('Patients can reach you for an instant consultation')
                : tr('Only booked appointments will reach you'),
            style: sizing.text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
