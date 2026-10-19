import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../domain/entities/voice_note.dart';
import 'voice_waveform.dart';

/// Play control, waveform and clock for one voice note.
///
/// Playback position is local to this widget — it is a view concern, not
/// something the thread's state needs to know about.
///
/// TODO(chat): back this with a real audio player. Only [_tick] and the
/// position it advances change; the controls and the waveform already read from
/// a position and a duration.
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({
    super.key,
    required this.note,
    required this.accentColor,
    required this.trackColor,
    required this.controlBackground,
    required this.controlForeground,
    required this.clockStyle,
  });

  final VoiceNote note;

  /// The played part of the waveform.
  final Color accentColor;

  /// The part still to play.
  final Color trackColor;

  final Color controlBackground;
  final Color controlForeground;
  final TextStyle clockStyle;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  static const Duration _tick = Duration(milliseconds: 200);

  Timer? _timer;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_isPlaying) {
      _pause();
      return;
    }

    // Starting again from the end replays the clip.
    if (_position >= widget.note.duration) _position = Duration.zero;

    setState(() => _isPlaying = true);
    _timer = Timer.periodic(_tick, (_) {
      setState(() {
        _position += _tick;
        if (_position >= widget.note.duration) {
          _position = widget.note.duration;
          _stopTimer();
          _isPlaying = false;
        }
      });
    });
  }

  void _pause() {
    _stopTimer();
    setState(() => _isPlaying = false);
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final note = widget.note;
    // The clock counts up while playing and shows the length at rest, which is
    // what a listener wants in each state.
    final clock = _position == Duration.zero
        ? note.durationLabel
        : VoiceNote.formatPosition(_position);

    return Row(
      children: [
        Semantics(
          button: true,
          label: _isPlaying ? tr('Pause voice note') : tr('Play voice note'),
          child: InkWell(
            onTap: _toggle,
            customBorder: const CircleBorder(),
            child: Container(
              width: sizing.iconButtonSize,
              height: sizing.iconButtonSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.controlBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: sizing.iconLg,
                color: widget.controlForeground,
              ),
            ),
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        Expanded(
          child: VoiceWaveform(
            amplitudes: note.waveform,
            progress: note.progressAt(_position),
            playedColor: widget.accentColor,
            remainingColor: widget.trackColor,
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        Text(clock, style: widget.clockStyle),
      ],
    );
  }
}
