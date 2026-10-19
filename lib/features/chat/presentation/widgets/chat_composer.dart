import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import 'voice_waveform.dart';

/// The bar at the foot of the thread: type a message, or hold the mic to
/// record one.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSendText,
    required this.onStartRecording,
    required this.onSendRecording,
    required this.onCancelRecording,
    required this.isRecording,
    required this.recordingLabel,
    required this.recordingWaveform,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSendText;

  final VoidCallback onStartRecording;
  final VoidCallback onSendRecording;
  final VoidCallback onCancelRecording;

  final bool isRecording;

  /// `0:07` — how long the current recording is.
  final String recordingLabel;

  /// Live amplitudes, drawn while recording.
  final List<double> recordingWaveform;

  final bool enabled;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Swaps the mic for the send button as soon as there is something to send.
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _send() {
    final body = widget.controller.text;
    if (body.trim().isEmpty) return;

    widget.controller.clear();
    widget.onSendText(body);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingXs,
        sizing.screenPaddingH,
        sizing.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: widget.isRecording
                ? _RecordingStrip(
                    label: widget.recordingLabel,
                    waveform: widget.recordingWaveform,
                  )
                : _TextInput(
                    controller: widget.controller,
                    enabled: widget.enabled,
                    onSubmitted: _send,
                  ),
          ),
          SizedBox(width: sizing.spacingXs),
          // The mic stays mounted while recording: it is holding the gesture,
          // and releasing it is what sends the note.
          if (_hasText && !widget.isRecording)
            _CircleAction(
              icon: Icons.send_rounded,
              label: tr('Send message'),
              onTap: widget.enabled ? _send : null,
            )
          else
            _MicButton(
              enabled: widget.enabled,
              isRecording: widget.isRecording,
              onStart: widget.onStartRecording,
              onFinish: widget.onSendRecording,
              onCancel: widget.onCancelRecording,
            ),
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      constraints: BoxConstraints(minHeight: sizing.searchFieldHeight),
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingMd,
        vertical: sizing.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusXl),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        // Grows to four lines, then scrolls, so the thread keeps most of the
        // screen even for a long message.
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: sizing.text.fieldValue,
        cursorColor: AppColors.primaryDeep,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: tr('Write a message'),
          hintStyle: sizing.text.fieldPlaceholder,
        ),
        onSubmitted: (_) => onSubmitted(),
      ),
    );
  }
}

/// What the text box becomes while a note is being recorded.
class _RecordingStrip extends StatelessWidget {
  const _RecordingStrip({required this.label, required this.waveform});

  final String label;
  final List<double> waveform;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      height: sizing.searchFieldHeight,
      padding: EdgeInsets.symmetric(horizontal: sizing.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusXl),
        border: Border.all(width: sizing.hairline, color: AppColors.danger),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fiber_manual_record,
            size: sizing.iconXs * 0.75,
            color: AppColors.danger,
          ),
          SizedBox(width: sizing.spacingXs),
          Text(
            label,
            style: sizing.text.metaLabel.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: sizing.spacingXs),
          Expanded(
            child: VoiceWaveform(
              amplitudes: waveform,
              // Everything recorded so far is "played" — the bar is a level
              // meter here rather than a progress track.
              progress: 1,
              alignRight: true,
              playedColor: AppColors.danger,
              remainingColor: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hold to record, release to send, drag away to discard.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.enabled,
    required this.isRecording,
    required this.onStart,
    required this.onFinish,
    required this.onCancel,
  });

  final bool enabled;

  /// Fills red while the press is being held, so it is clear what releasing
  /// will do.
  final bool isRecording;

  final VoidCallback onStart;
  final VoidCallback onFinish;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      button: true,
      label: isRecording
          ? tr('Release to send the voice note')
          : tr('Hold to record a voice note'),
      child: GestureDetector(
        onLongPressStart: enabled ? (_) => onStart() : null,
        onLongPressEnd: enabled ? (_) => onFinish() : null,
        // A drag off the button while holding abandons the recording.
        onLongPressMoveUpdate: enabled
            ? (details) {
                if (details.localOffsetFromOrigin.distance >
                    sizing.iconChipSize) {
                  onCancel();
                }
              }
            : null,
        child: Container(
          width: sizing.buttonHeight,
          height: sizing.buttonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: switch ((isRecording, enabled)) {
              (true, _) => AppColors.danger,
              (false, true) => AppColors.surfaceMuted,
              (false, false) => AppColors.surfaceMuted.withValues(alpha: 0.5),
            },
            shape: BoxShape.circle,
            border: Border.all(
              width: sizing.hairline,
              color: isRecording ? AppColors.danger : AppColors.border,
            ),
          ),
          child: Icon(
            isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
            size: sizing.iconMd,
            color: switch ((isRecording, enabled)) {
              (true, _) => Colors.white,
              (false, true) => AppColors.primaryDeep,
              (false, false) => AppColors.textTertiary,
            },
          ),
        ),
      ),
    );
  }
}

/// The round send button beside the composer.
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: sizing.buttonHeight,
          height: sizing.buttonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onTap == null
                ? AppColors.primaryDeep.withValues(alpha: 0.45)
                : AppColors.primaryDeep,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: sizing.iconSm, color: Colors.white),
        ),
      ),
    );
  }
}
