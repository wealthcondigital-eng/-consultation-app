import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/logging/auth_logger.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/recording_source.dart';
import '../../domain/entities/call_recording.dart';

class RecordingPlayerArgs {
  const RecordingPlayerArgs({required this.recording});

  final CallRecording recording;
}

/// Plays one consultation recording, video or audio.
///
/// The phone's own copy when there is one — it is the patient's, it plays
/// offline and costs no data — otherwise the server's, streamed with the
/// session's token since recordings are never public URLs.
class RecordingPlayerScreen extends StatefulWidget {
  const RecordingPlayerScreen({super.key, required this.args});

  final RecordingPlayerArgs args;

  @override
  State<RecordingPlayerScreen> createState() => _RecordingPlayerScreenState();
}

class _RecordingPlayerScreenState extends State<RecordingPlayerScreen> {
  VideoPlayerController? _player;
  String? _error;

  CallRecording get _recording => widget.args.recording;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final player = await recordingPlayer(_recording);

      await player.initialize();
      if (!mounted) {
        await player.dispose();
        return;
      }

      player.addListener(_onTick);
      setState(() => _player = player);
      await player.play();
    } catch (error) {
      AuthLogger.event('RECORDING · could not play', {
        'id': _recording.id,
        'error': '$error',
      });
      if (mounted) {
        setState(
          () => _error =
              'This recording could not be played. Check your connection '
              'and try again.',
        );
      }
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player
      ?..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final player = _player;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: sizing.spacingXs),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: tr('Back'),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: sizing.iconMd,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(
                              _recording.isVideo
                                  ? 'Video consultation recording'
                                  : 'Audio consultation recording',
                            ),
                            style: sizing.text.cardTitle.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${AppDateFormat.dayMonthYear(_recording.recordedAt)}'
                            ' · ${AppDateFormat.clockTime(_recording.recordedAt)}',
                            style: sizing.text.cardSubtitle.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: switch ((player, _error)) {
                    (_, final error?) => Padding(
                      padding: EdgeInsets.all(sizing.screenPaddingH),
                      child: Text(
                        tr(error),
                        textAlign: TextAlign.center,
                        style: sizing.text.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    (null, _) => const CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    (final ready?, _) =>
                      _recording.isVideo && ready.value.size.width > 0
                          ? AspectRatio(
                              aspectRatio: ready.value.aspectRatio,
                              child: VideoPlayer(ready),
                            )
                          : _AudioArt(playing: ready.value.isPlaying),
                  },
                ),
              ),
              if (player != null) _Controls(player: player),
            ],
          ),
        ),
      ),
    );
  }
}

/// What an audio recording shows where a video would be.
class _AudioArt extends StatelessWidget {
  const _AudioArt({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: sizing.r(playing ? 150 : 136),
      height: sizing.r(playing ? 150 : 136),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.anonymousAccent.icon.withValues(alpha: 0.25),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.graphic_eq_rounded,
        size: sizing.r(64),
        color: Colors.white,
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.player});

  final VideoPlayerController player;

  static String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final value = player.value;
    final total = value.duration.inMilliseconds;
    final position = value.position.inMilliseconds.clamp(0, total);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        0,
        sizing.screenPaddingH,
        sizing.spacingMd,
      ),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: sizing.r(3),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: total == 0 ? 0 : position / total,
              onChanged: total == 0
                  ? null
                  : (fraction) => player.seekTo(
                      Duration(milliseconds: (fraction * total).round()),
                    ),
            ),
          ),
          Row(
            children: [
              Text(
                _clock(value.position),
                style: sizing.text.badgeLabel.copyWith(color: Colors.white70),
              ),
              const Spacer(),
              IconButton(
                onPressed: () =>
                    player.seekTo(value.position - const Duration(seconds: 10)),
                tooltip: tr('Back 10 seconds'),
                icon: Icon(
                  Icons.replay_10_rounded,
                  color: Colors.white,
                  size: sizing.iconLg,
                ),
              ),
              SizedBox(width: sizing.spacingSm),
              IconButton.filled(
                onPressed: () =>
                    value.isPlaying ? player.pause() : player.play(),
                tooltip: tr(value.isPlaying ? 'Pause' : 'Play'),
                style: IconButton.styleFrom(backgroundColor: Colors.white),
                icon: Icon(
                  value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: sizing.iconLg,
                ),
              ),
              SizedBox(width: sizing.spacingSm),
              IconButton(
                onPressed: () =>
                    player.seekTo(value.position + const Duration(seconds: 10)),
                tooltip: tr('Forward 10 seconds'),
                icon: Icon(
                  Icons.forward_10_rounded,
                  color: Colors.white,
                  size: sizing.iconLg,
                ),
              ),
              const Spacer(),
              Text(
                _clock(value.duration),
                style: sizing.text.badgeLabel.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
