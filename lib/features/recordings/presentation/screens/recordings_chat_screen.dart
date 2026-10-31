import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/session/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../data/recordings_remote_data_source.dart';
import '../../domain/entities/call_recording.dart';
import '../controllers/recordings_controller.dart';
import '../widgets/recording_bubbles.dart';
import '../widgets/transcript_panel.dart';

/// Opens the chat with the other person in [appointment] — from a past
/// consultation in the appointment history.
///
/// The appointment names a doctor by the doctor record's id and a patient by
/// their user id; the server's thread filter takes either.
Future<void> openRecordingsChat(
  BuildContext context,
  Appointment appointment,
) async {
  final counterpartId = appointment.counterpartId;
  if (counterpartId == null || appointment.isAnonymous) return;

  await Navigator.of(context).pushNamed(
    AppRoutes.chat,
    arguments: RecordingsChatArgs(
      counterpart: RecordingParty(
        userId: counterpartId,
        name: appointment.counterpartName,
      ),
    ),
  );
}

/// Who the recordings chat is with.
class RecordingsChatArgs {
  const RecordingsChatArgs({required this.counterpart});

  final RecordingParty counterpart;
}

/// The chat between one patient and one doctor — and only their call
/// recordings are in it.
///
/// Laid out like a conversation so it reads as "our consultations", oldest
/// at the top. There is deliberately no composer: messaging between patient
/// and doctor outside a consultation is not offered, and the footer says so
/// instead of leaving an empty space where a text box would be.
class RecordingsChatScreen extends StatefulWidget {
  const RecordingsChatScreen({super.key, required this.args});

  final RecordingsChatArgs args;

  @override
  State<RecordingsChatScreen> createState() => _RecordingsChatScreenState();
}

class _RecordingsChatScreenState extends State<RecordingsChatScreen> {
  late final String? _viewer = sl<AuthSession>().userId;

  late final RecordingsController _controller = RecordingsController(
    sl<RecordingsRemoteDataSource>(),
    viewerUserId: _viewer,
  )..load(withUserId: widget.args.counterpart.userId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final counterpart = widget.args.counterpart;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        scrollable: false,
        backgroundColor: AppColors.canvas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(counterpart: counterpart),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final recordings = _controller.recordings;

                  if (_controller.isLoading && recordings.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return AppRefreshIndicator(
                    onRefresh: () =>
                        _controller.load(withUserId: counterpart.userId),
                    child: ListView(
                      // Newest at the bottom, where a chat ends.
                      reverse: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        sizing.screenPaddingH,
                        sizing.spacingMd,
                        sizing.screenPaddingH,
                        sizing.spacingMd,
                      ),
                      children: [
                        if (recordings.isEmpty)
                          _EmptyThread(error: _controller.error)
                        else
                          // Reversed list: each bubble, then — above it — the
                          // day chip when it is the first of its day.
                          for (final (index, recording)
                              in recordings.indexed) ...[
                            // Reversed list, so earlier children sit lower:
                            // the transcript is listed first to draw under its
                            // recording.
                            TranscriptPanel(
                              recording: recording,
                              mine: recording.patientUserId == _viewer,
                            ),
                            RecordingBubble(
                              recording: recording,
                              // Recorded on the patient's phone, so it sits on
                              // the patient's side of the chat.
                              mine: recording.patientUserId == _viewer,
                            ),
                            SizedBox(height: sizing.spacingMd),
                            if (index == recordings.length - 1 ||
                                !_sameDay(
                                  recordings[index + 1].recordedAt,
                                  recording.recordedAt,
                                )) ...[
                              RecordingDayChip(date: recording.recordedAt),
                              SizedBox(height: sizing.spacingSm),
                            ],
                          ],
                        const _Notice(),
                      ],
                    ),
                  );
                },
              ),
            ),
            const _ReadOnlyFooter(),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _Header extends StatelessWidget {
  const _Header({required this.counterpart});

  final RecordingParty counterpart;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
        sizing.spacingXs,
        MediaQuery.paddingOf(context).top + sizing.spacingXs,
        sizing.screenPaddingH,
        sizing.spacingSm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: tr('Back'),
            icon: Icon(Icons.arrow_back_rounded, size: sizing.iconMd),
          ),
          RemoteAvatar(
            path: counterpart.photoUrl,
            initials: initialsOf(counterpart.name),
            size: sizing.r(40),
            semanticLabel: counterpart.name,
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  counterpart.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sizing.text.cardTitle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  tr('Consultation recordings'),
                  style: sizing.text.cardSubtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// At the top of the thread: what this chat is for.
class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.only(bottom: sizing.spacingMd),
      child: Container(
        padding: EdgeInsets.all(sizing.spacingSm),
        decoration: BoxDecoration(
          color: AppColors.warningSurface,
          borderRadius: BorderRadius.circular(sizing.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_rounded,
              size: sizing.iconSm,
              color: AppColors.warning,
            ),
            SizedBox(width: sizing.spacingXs),
            Expanded(
              child: Text(
                tr(
                  'Your consultation recordings with this doctor or patient '
                  'appear here. They are private to the two of you.',
                ),
                style: sizing.text.bodySmall.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: sizing.spacingXl),
      child: Text(
        tr(error ?? 'No recordings yet.'),
        textAlign: TextAlign.center,
        style: sizing.text.cardSubtitle,
      ),
    );
  }
}

/// Where a chat's text box would be: why there isn't one.
class _ReadOnlyFooter extends StatelessWidget {
  const _ReadOnlyFooter();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingSm,
        sizing.screenPaddingH,
        sizing.spacingSm + MediaQuery.paddingOf(context).bottom,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: sizing.spacingMd,
          vertical: sizing.spacingSm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(sizing.radiusPill),
          border: Border.all(color: AppColors.border, width: sizing.hairline),
        ),
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: sizing.iconSm,
              color: AppColors.textTertiary,
            ),
            SizedBox(width: sizing.spacingXs),
            Expanded(
              child: Text(
                tr(
                  'Messaging is not available. Only call recordings are '
                  'shared here.',
                ),
                style: sizing.text.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
