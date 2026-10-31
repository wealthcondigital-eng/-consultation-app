import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/logging/auth_logger.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/recording_source.dart';
import '../../domain/entities/call_recording.dart';
import '../screens/recording_player_screen.dart';

/// One recording in the chat: a voice message for an audio call, a video tile
/// for a video call — the two shapes people already know from WhatsApp.
class RecordingBubble extends StatelessWidget {
  const RecordingBubble({
    super.key,
    required this.recording,
    required this.mine,
  });

  final CallRecording recording;

  /// On the viewer's side of the chat. The patient's phone made the
  /// recording, so it is "mine" to the patient and "theirs" to the doctor.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final tail = Radius.circular(sizing.radiusXs);
    final round = Radius.circular(sizing.radiusLg);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: min(MediaQuery.sizeOf(context).width * 0.8, sizing.r(320)),
        ),
        child: Container(
          padding: EdgeInsets.all(sizing.r(6)),
          decoration: BoxDecoration(
            color: mine ? AppColors.primarySurface : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: round,
              topRight: round,
              bottomLeft: mine ? round : tail,
              bottomRight: mine ? tail : round,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: sizing.r(4),
                offset: Offset(0, sizing.r(1)),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (recording.isVideo)
                _VideoTile(
                  key: ValueKey('recording-video-${recording.id}'),
                  recording: recording,
                )
              else
                _VoiceMessage(recording: recording, mine: mine),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  sizing.r(6),
                  sizing.r(4),
                  sizing.r(4),
                  0,
                ),
                child: Row(
                  children: [
                    Icon(
                      recording.isVideo
                          ? Icons.videocam_rounded
                          : Icons.mic_rounded,
                      size: sizing.r(13),
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(width: sizing.r(4)),
                    Expanded(
                      child: Text(
                        tr(
                          recording.isVideo
                              ? 'Video call recording'
                              : 'Audio call recording',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sizing.text.metaLabel.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      AppDateFormat.clockTime(recording.recordedAt),
                      style: sizing.text.metaLabel.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: sizing.sp(11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A video call: a dark tile with a play button and the length, opening the
/// full-screen player.
class _VideoTile extends StatelessWidget {
  const _VideoTile({super.key, required this.recording});

  final CallRecording recording;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusMd);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: () => Navigator.of(context).pushNamed(
          AppRoutes.recordingPlayer,
          arguments: RecordingPlayerArgs(recording: recording),
        ),
        child: Ink(
          height: sizing.r(160),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryDeep, AppColors.inkDeep],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Icon(
                  Icons.videocam_rounded,
                  size: sizing.r(110),
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              Center(
                child: Container(
                  width: sizing.r(56),
                  height: sizing.r(56),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: sizing.r(1.5),
                    ),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: sizing.r(34),
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                left: sizing.spacingSm,
                bottom: sizing.spacingXs,
                right: sizing.spacingSm,
                child: Row(
                  children: [
                    Icon(
                      Icons.videocam_rounded,
                      size: sizing.iconXs,
                      color: Colors.white,
                    ),
                    SizedBox(width: sizing.r(4)),
                    Text(
                      recording.durationLabel,
                      style: sizing.text.badgeLabel.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      recording.sizeLabel,
                      style: sizing.text.badgeLabel.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The voice message currently playing, so starting another one stops it —
/// two consultations talking over each other help nobody.
final ValueNotifier<String?> _playingVoice = ValueNotifier(null);

/// An audio call, played in place like a WhatsApp voice message: play and
/// pause, a waveform that fills as it plays and can be dragged to seek, the
/// time, and a speed toggle.
class _VoiceMessage extends StatefulWidget {
  const _VoiceMessage({required this.recording, required this.mine});

  final CallRecording recording;
  final bool mine;

  @override
  State<_VoiceMessage> createState() => _VoiceMessageState();
}

class _VoiceMessageState extends State<_VoiceMessage> {
  VideoPlayerController? _player;
  bool _loading = false;
  bool _failed = false;
  double _speed = 1;

  /// Bar heights, fixed per recording so the same message always looks the
  /// same. Decorative: the file's real loudness is not read.
  late final List<double> _bars = () {
    final random = Random(widget.recording.id.hashCode);
    return [for (var i = 0; i < 34; i++) 0.25 + random.nextDouble() * 0.75];
  }();

  @override
  void initState() {
    super.initState();
    _playingVoice.addListener(_onOtherStarted);
  }

  @override
  void dispose() {
    _playingVoice.removeListener(_onOtherStarted);
    if (_playingVoice.value == widget.recording.id) _playingVoice.value = null;
    _player
      ?..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  void _onOtherStarted() {
    if (_playingVoice.value != widget.recording.id) _player?.pause();
  }

  void _onTick() {
    final player = _player;
    if (player == null || !mounted) return;

    // Played to the end: back to the start, ready to play again.
    final value = player.value;
    if (!value.isPlaying &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      player.seekTo(Duration.zero);
    }
    setState(() {});
  }

  Future<void> _toggle() async {
    final existing = _player;
    if (existing != null) {
      if (existing.value.isPlaying) {
        await existing.pause();
      } else {
        _playingVoice.value = widget.recording.id;
        await existing.play();
      }
      return;
    }

    setState(() {
      _loading = true;
      _failed = false;
    });

    try {
      final player = await recordingPlayer(widget.recording);
      await player.initialize();
      if (!mounted) {
        await player.dispose();
        return;
      }
      player
        ..addListener(_onTick)
        ..setPlaybackSpeed(_speed);
      _player = player;
      _playingVoice.value = widget.recording.id;
      await player.play();
    } catch (error) {
      AuthLogger.event('RECORDING · voice message could not play', {
        'id': widget.recording.id,
        'error': '$error',
      });
      _failed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _cycleSpeed() {
    setState(() => _speed = _speed == 1 ? 1.5 : (_speed == 1.5 ? 2 : 1));
    _player?.setPlaybackSpeed(_speed);
  }

  void _seekTo(double fraction) {
    final player = _player;
    if (player == null) return;
    final total = player.value.duration.inMilliseconds;
    player.seekTo(
      Duration(milliseconds: (fraction.clamp(0, 1) * total).round()),
    );
  }

  static String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final accent = AppColors.primary;
    final value = _player?.value;
    final total = value?.duration ?? widget.recording.duration;
    final position = value?.position ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final playing = value?.isPlaying ?? false;
    final started = position > Duration.zero || playing;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        sizing.r(4),
        sizing.r(6),
        sizing.r(6),
        sizing.r(2),
      ),
      child: Row(
        children: [
          // The mic avatar, as on a forwarded voice note.
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: sizing.r(22),
                backgroundColor: AppColors.avatarSurface,
                child: Icon(
                  Icons.headset_mic_rounded,
                  size: sizing.r(22),
                  color: AppColors.primaryDeep,
                ),
              ),
              Positioned(
                right: -sizing.r(2),
                bottom: -sizing.r(2),
                child: Icon(
                  Icons.mic_rounded,
                  size: sizing.r(16),
                  color: playing ? accent : AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(width: sizing.spacingXs),
          SizedBox(
            width: sizing.r(36),
            height: sizing.r(36),
            child: _loading
                ? Padding(
                    padding: EdgeInsets.all(sizing.r(8)),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: accent,
                    ),
                  )
                : IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _toggle,
                    tooltip: tr(playing ? 'Pause' : 'Play'),
                    icon: Icon(
                      _failed
                          ? Icons.refresh_rounded
                          : playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: sizing.r(32),
                      color: _failed ? AppColors.danger : AppColors.textLabel,
                    ),
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: sizing.r(30),
                  child: LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _seekTo(
                        details.localPosition.dx / constraints.maxWidth,
                      ),
                      onHorizontalDragUpdate: (details) => _seekTo(
                        details.localPosition.dx / constraints.maxWidth,
                      ),
                      child: _Waveform(
                        bars: _bars,
                        progress: progress,
                        played: accent,
                        unplayed: AppColors.textTertiary.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _failed
                          ? tr('Tap to retry')
                          : _clock(started ? position : total),
                      style: sizing.text.metaLabel.copyWith(
                        color: _failed
                            ? AppColors.danger
                            : AppColors.textSecondary,
                        fontSize: sizing.sp(11),
                      ),
                    ),
                    const Spacer(),
                    if (started)
                      InkWell(
                        onTap: _cycleSpeed,
                        borderRadius: BorderRadius.circular(sizing.radiusPill),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: sizing.r(7),
                            vertical: sizing.r(1),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.18,
                            ),
                            borderRadius: BorderRadius.circular(
                              sizing.radiusPill,
                            ),
                          ),
                          child: Text(
                            '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}×',
                            style: sizing.text.metaLabel.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: sizing.sp(11),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.bars,
    required this.progress,
    required this.played,
    required this.unplayed,
  });

  final List<double> bars;
  final double progress;
  final Color played;
  final Color unplayed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaveformPainter(bars, progress, played, unplayed),
      size: Size.infinite,
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.bars, this.progress, this.played, this.unplayed);

  final List<double> bars;
  final double progress;
  final Color played;
  final Color unplayed;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width / bars.length;
    final width = max(2.0, gap * 0.55);
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < bars.length; i++) {
      final x = gap * i + gap / 2;
      final height = size.height * 0.8 * bars[i];
      paint
        ..color = (i + 0.5) / bars.length <= progress ? played : unplayed
        ..strokeWidth = width;
      canvas.drawLine(
        Offset(x, size.height / 2 - height / 2),
        Offset(x, size.height / 2 + height / 2),
        paint,
      );
    }

    // The playhead dot, where WhatsApp puts it.
    final dotX = (size.width * progress).clamp(4.0, size.width - 4.0);
    canvas.drawCircle(
      Offset(dotX, size.height / 2),
      5,
      Paint()..color = played,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.played != played;
}

/// "Today", "Yesterday" or the date, between days in the chat.
class RecordingDayChip extends StatelessWidget {
  const RecordingDayChip({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: sizing.spacingSm,
          vertical: sizing.r(4),
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(sizing.radiusSm),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: sizing.r(3),
            ),
          ],
        ),
        child: Text(
          AppDateFormat.dayLabel(date),
          style: sizing.text.metaLabel.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
