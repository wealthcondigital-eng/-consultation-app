import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/session/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../data/recordings_remote_data_source.dart';
import '../../domain/entities/call_recording.dart';
import '../controllers/recordings_controller.dart';
import 'recordings_chat_screen.dart';

/// Every recorded consultation, grouped by the other person: a card per
/// doctor (or, on a doctor's phone, per patient) listing their consultations.
/// Tapping either opens that pair's chat, where the recordings play and their
/// transcripts are.
class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  late final RecordingsController _controller = RecordingsController(
    sl<RecordingsRemoteDataSource>(),
    viewerUserId: sl<AuthSession>().userId,
  )..load();

  _KindFilter _filter = _KindFilter.all;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(RecordingParty counterpart) => Navigator.of(context)
      .pushNamed(
        AppRoutes.chat,
        arguments: RecordingsChatArgs(counterpart: counterpart),
      )
      .then((_) => _controller.load());

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.canvas,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        scrollable: false,
        backgroundColor: AppColors.canvas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppTopBar(
              title: 'Call recordings',
              variant: AppTopBarVariant.outlined,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final all = _controller.threads;
                  // The chips narrow each person's list to one kind of call,
                  // and drop anyone left with none.
                  final threads = [
                    for (final thread in all) ?_filter.keep(thread),
                  ];

                  if (_controller.isLoading && all.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return AppRefreshIndicator(
                    onRefresh: _controller.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        sizing.screenPaddingH,
                        sizing.spacingXs,
                        sizing.screenPaddingH,
                        sizing.spacingXl,
                      ),
                      children: [
                        if (all.isEmpty)
                          _Empty(error: _controller.error)
                        else ...[
                          _Summary(recordings: _controller.recordings),
                          SizedBox(height: sizing.spacingMd),
                          _FilterChips(
                            selected: _filter,
                            onSelected: (filter) =>
                                setState(() => _filter = filter),
                          ),
                          SizedBox(height: sizing.spacingMd),
                          if (threads.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: sizing.spacingXl,
                              ),
                              child: Text(
                                tr('No recordings of this kind yet.'),
                                textAlign: TextAlign.center,
                                style: sizing.text.cardSubtitle,
                              ),
                            ),
                          for (final thread in threads) ...[
                            _ThreadCard(
                              thread: thread,
                              onOpen: () => _open(thread.counterpart),
                            ),
                            SizedBox(height: sizing.spacingMd),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One person, and the consultations recorded with them.
class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread, required this.onOpen});

  final RecordingThread thread;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final count = thread.recordings.length;
    final radius = BorderRadius.circular(sizing.radiusLg);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: EdgeInsets.all(sizing.cardPadding),
              child: Row(
                children: [
                  RemoteAvatar(
                    path: thread.counterpart.photoUrl,
                    initials: initialsOf(thread.counterpart.name),
                    size: sizing.r(48),
                    semanticLabel: thread.counterpart.name,
                  ),
                  SizedBox(width: sizing.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          thread.counterpart.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: sizing.text.cardTitle.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: sizing.spacingXxs),
                        Text(
                          tr(
                            count == 1
                                ? '1 consultation recorded'
                                : '{n} consultations recorded',
                            {'n': count},
                          ),
                          style: sizing.text.cardSubtitle,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: sizing.spacingSm,
                      vertical: sizing.r(6),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(sizing.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_rounded,
                          size: sizing.iconXs,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: sizing.r(4)),
                        Text(
                          tr('Open chat'),
                          style: sizing.text.metaLabel.copyWith(
                            color: AppColors.primaryDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: sizing.hairline, color: AppColors.dividerFaint),
          for (final (index, recording) in thread.recordings.indexed)
            _ConsultationRow(
              recording: recording,
              showDivider: index < thread.recordings.length - 1,
              onTap: onOpen,
            ),
        ],
      ),
    );
  }
}

/// One recorded consultation: what kind, when, how long, and whether its
/// transcript is ready.
class _ConsultationRow extends StatelessWidget {
  const _ConsultationRow({
    required this.recording,
    required this.showDivider,
    required this.onTap,
  });

  final CallRecording recording;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final accent = recording.isVideo
        ? AppColors.consultAccent
        : AppColors.anonymousAccent;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: sizing.cardPadding,
          vertical: sizing.spacingSm,
        ),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: AppColors.dividerFaint,
                    width: sizing.hairline,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: sizing.r(38),
              height: sizing.r(38),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.surface,
                borderRadius: BorderRadius.circular(sizing.radiusMd),
              ),
              child: Icon(
                recording.isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
                size: sizing.iconSm,
                color: accent.icon,
              ),
            ),
            SizedBox(width: sizing.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      recording.isVideo
                          ? 'Video consultation'
                          : 'Audio consultation',
                    ),
                    style: sizing.text.cardTitle.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: sizing.sp(14),
                    ),
                  ),
                  SizedBox(height: sizing.r(2)),
                  Text(
                    '${AppDateFormat.dayMonthYear(recording.recordedAt)} · '
                    '${AppDateFormat.clockTime(recording.recordedAt)} · '
                    '${recording.durationLabel}',
                    style: sizing.text.cardSubtitle,
                  ),
                ],
              ),
            ),
            if (recording.transcript.hasText)
              Tooltip(
                message: tr('Transcript available'),
                child: Icon(
                  Icons.subject_rounded,
                  size: sizing.iconSm,
                  color: AppColors.primary,
                ),
              ),
            SizedBox(width: sizing.spacingXxs),
            Icon(
              Icons.chevron_right_rounded,
              size: sizing.iconMd,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.only(top: sizing.spacingXl * 2),
      child: Column(
        children: [
          Container(
            width: sizing.r(72),
            height: sizing.r(72),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.video_library_rounded,
              size: sizing.r(34),
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: sizing.spacingMd),
          Text(
            tr(error ?? 'No recordings yet'),
            textAlign: TextAlign.center,
            style: sizing.text.cardTitle.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: sizing.spacingXs),
          Text(
            tr(
              'Recordings of your audio and video consultations will appear '
              'here.',
            ),
            textAlign: TextAlign.center,
            style: sizing.text.cardSubtitle,
          ),
        ],
      ),
    );
  }
}

/// All, video only, or audio only.
enum _KindFilter {
  all('All'),
  video('Video'),
  audio('Audio');

  const _KindFilter(this.label);

  final String label;

  /// [thread] narrowed to this kind of call, or null when none are left.
  RecordingThread? keep(RecordingThread thread) {
    if (this == all) return thread;
    final kept = [
      for (final recording in thread.recordings)
        if (recording.isVideo == (this == video)) recording,
    ];
    return kept.isEmpty
        ? null
        : RecordingThread(counterpart: thread.counterpart, recordings: kept);
  }
}

/// The brand card at the top: how many, how long, how many have transcripts,
/// and who can see them.
class _Summary extends StatelessWidget {
  const _Summary({required this.recordings});

  final List<CallRecording> recordings;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final total = recordings.fold(
      Duration.zero,
      (sum, recording) => sum + recording.duration,
    );
    final minutes = (total.inSeconds / 60).ceil();
    final transcribed = recordings
        .where((recording) => recording.transcript.hasText)
        .length;

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: sizing.text.cardTitleLarge.copyWith(
              color: AppColors.onBrand,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            tr(label),
            textAlign: TextAlign.center,
            style: sizing.text.metaLabel.copyWith(
              color: AppColors.onBrandMuted,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        gradient: AppColors.brandSweep,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              stat('${recordings.length}', 'Recordings'),
              Container(
                width: sizing.hairline,
                height: sizing.r(36),
                color: AppColors.onBrandBorder,
              ),
              stat('$minutes', 'Minutes'),
              Container(
                width: sizing.hairline,
                height: sizing.r(36),
                color: AppColors.onBrandBorder,
              ),
              stat('$transcribed', 'Transcripts'),
            ],
          ),
          SizedBox(height: sizing.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                size: sizing.iconXs,
                color: AppColors.onBrandMuted,
              ),
              SizedBox(width: sizing.r(4)),
              Flexible(
                child: Text(
                  tr('Private to you and the other person in the call'),
                  style: sizing.text.metaLabel.copyWith(
                    color: AppColors.onBrandMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final _KindFilter selected;
  final ValueChanged<_KindFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      children: [
        for (final filter in _KindFilter.values) ...[
          ChoiceChip(
            label: Text(tr(filter.label)),
            selected: filter == selected,
            onSelected: (_) => onSelected(filter),
            showCheckmark: false,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: filter == selected ? AppColors.primary : AppColors.border,
              width: sizing.hairline,
            ),
            labelStyle: sizing.text.chipLabel.copyWith(
              color: filter == selected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            avatar: switch (filter) {
              _KindFilter.all => null,
              _KindFilter.video => Icon(
                Icons.videocam_rounded,
                size: sizing.iconXs,
                color: filter == selected ? Colors.white : AppColors.primary,
              ),
              _KindFilter.audio => Icon(
                Icons.mic_rounded,
                size: sizing.iconXs,
                color: filter == selected ? Colors.white : AppColors.primary,
              ),
            },
          ),
          SizedBox(width: sizing.spacingXs),
        ],
      ],
    );
  }
}
