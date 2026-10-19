import 'package:flutter/material.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';

/// The controls at the foot of a call.
///
/// Two things changed here when the audio call was fixed:
///
///  * **The speaker button says which route is live**, and names it. On a voice
///    call the choice is speaker-or-earpiece and a volume glyph describes
///    neither — it reads as loudness, so tapping it looks like it should make
///    the call louder. It is a speaker/earpiece pair now, captioned.
///  * **Every control is captioned.** A row of unlabelled circles on a black
///    ground is guesswork under pressure, and the one that matters — hanging up
///    — was the same size and shape as the rest.
class CallControlsBar extends StatelessWidget {
  const CallControlsBar({
    super.key,
    required this.isAudioMuted,
    required this.isVideoMuted,
    required this.isSpeakerOn,
    required this.isFrontCamera,
    required this.isVideoCall,
    required this.onToggleAudio,
    required this.onToggleVideo,
    required this.onSwitchCamera,
    required this.onToggleSpeaker,
    required this.onEndCall,
  });

  final bool isAudioMuted;
  final bool isVideoMuted;
  final bool isSpeakerOn;
  final bool isFrontCamera;
  final bool isVideoCall;
  final VoidCallback onToggleAudio;
  final VoidCallback onToggleVideo;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onEndCall;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingMd,
        vertical: sizing.spacingSm,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(sizing.r(36)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ControlButton(
            icon: isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: isAudioMuted ? 'Unmute' : 'Mute',
            isOn: !isAudioMuted,
            onPressed: onToggleAudio,
            onColor: Colors.white.withValues(alpha: 0.2),
            offColor: AppColors.danger,
          ),
          SizedBox(width: sizing.spacingSm),

          // Speaker or earpiece — a route, not a volume. The old volume-up and
          // volume-down pair read as louder and quieter.
          _ControlButton(
            icon: isSpeakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
            label: isSpeakerOn ? 'Speaker' : 'Earpiece',
            isOn: isSpeakerOn,
            onPressed: onToggleSpeaker,
            onColor: AppColors.primary,
            offColor: Colors.white.withValues(alpha: 0.12),
          ),
          SizedBox(width: sizing.spacingSm),

          if (isVideoCall) ...[
            _ControlButton(
              icon: isVideoMuted
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              label: isVideoMuted ? 'Camera off' : 'Camera',
              isOn: !isVideoMuted,
              onPressed: onToggleVideo,
              onColor: Colors.white.withValues(alpha: 0.2),
              offColor: AppColors.danger,
            ),
            SizedBox(width: sizing.spacingSm),
            _ControlButton(
              icon: Icons.cameraswitch_rounded,
              label: isFrontCamera ? 'Front' : _rearCameraLabel(),
              isOn: true,
              onPressed: onSwitchCamera,
              onColor: Colors.white.withValues(alpha: 0.2),
              offColor: Colors.white.withValues(alpha: 0.12),
            ),
            SizedBox(width: sizing.spacingSm),
          ],

          _ControlButton(
            icon: Icons.call_end_rounded,
            label: 'End',
            isOn: false,
            onPressed: onEndCall,
            onColor: AppColors.danger,
            offColor: AppColors.danger,
            // Bigger than the rest. It is the one control that has to be
            // findable without reading, and it was the same circle as Mute.
            size: sizing.r(56),
          ),
        ],
      ),
    );
  }
}

/// `Back` for the rear camera. Looked up under its own key, because the bare
/// word `Back` is already the navigation label everywhere else and means
/// something different there. English keeps the short word.
String _rearCameraLabel() {
  final label = tr('Rear camera');
  return label == 'Rear camera' ? 'Back' : label;
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isOn,
    required this.onPressed,
    required this.onColor,
    required this.offColor,
    this.size,
  });

  final IconData icon;

  /// Shown under the button, and read out by a screen reader in place of the
  /// glyph.
  final String label;

  final bool isOn;
  final VoidCallback onPressed;
  final Color onColor;
  final Color offColor;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final buttonSize = size ?? sizing.r(48);

    return Semantics(
      button: true,
      label: tr(label),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: isOn ? onColor : offColor,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: buttonSize,
                height: buttonSize,
                child: Icon(icon, size: sizing.r(24), color: Colors.white),
              ),
            ),
          ),
          SizedBox(height: sizing.spacingXxs),
          // Excluded from semantics: the Semantics wrapper above already
          // announces it, and a screen reader should not read it twice.
          ExcludeSemantics(
            child: Text(
              tr(label),
              style: sizing.text.metaLabel.copyWith(
                color: Colors.white70,
                fontSize: sizing.sp(10),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
