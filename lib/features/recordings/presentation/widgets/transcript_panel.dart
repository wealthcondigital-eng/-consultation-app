import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/call_recording.dart';

/// The written-out call, under its recording in the chat.
///
/// Long consultations make long transcripts, so it opens folded to a few
/// lines with "Show full transcript"; unfolded it is split into the timed
/// stretches the server heard, which is how someone finds "what did the doctor
/// say about the dose" again.
class TranscriptPanel extends StatefulWidget {
  const TranscriptPanel({
    super.key,
    required this.recording,
    required this.mine,
  });

  final CallRecording recording;

  /// Lined up with its recording's side of the chat.
  final bool mine;

  @override
  State<TranscriptPanel> createState() => _TranscriptPanelState();
}

class _TranscriptPanelState extends State<TranscriptPanel> {
  bool _expanded = false;

  static String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final transcript = widget.recording.transcript;

    final Widget body;
    if (transcript.hasText) {
      final segments = transcript.segments;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_expanded && segments.isNotEmpty)
            for (final segment in segments)
              Padding(
                padding: EdgeInsets.only(bottom: sizing.spacingXs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: sizing.r(40),
                      child: Text(
                        _clock(segment.start),
                        style: sizing.text.metaLabel.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: sizing.sp(11),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        segment.text,
                        style: sizing.text.bodySmall.copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              )
          else
            Text(
              transcript.text,
              maxLines: _expanded ? null : 4,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: sizing.text.bodySmall.copyWith(height: 1.45),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.only(top: sizing.spacingXxs),
              child: Text(
                tr(_expanded ? 'Show less' : 'Show full transcript'),
                style: sizing.text.sectionAction.copyWith(
                  fontSize: sizing.sp(12),
                ),
              ),
            ),
          ),
          // Machine-written from the audio: a reminder of that, so nobody
          // reads a misheard medicine name as what the doctor said.
          Padding(
            padding: EdgeInsets.only(top: sizing.spacingXs),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: sizing.r(12),
                  color: AppColors.textTertiary,
                ),
                SizedBox(width: sizing.r(4)),
                Expanded(
                  child: Text(
                    tr('Auto-generated · may contain errors'),
                    style: sizing.text.metaLabel.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: sizing.sp(11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      final preparing = transcript.status == TranscriptStatus.preparing;
      body = Row(
        children: [
          if (preparing) ...[
            SizedBox.square(
              dimension: sizing.r(12),
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: AppColors.textTertiary,
              ),
            ),
            SizedBox(width: sizing.spacingXs),
          ],
          Expanded(
            child: Text(
              tr(
                preparing
                    ? 'Transcript is being prepared…'
                    : 'No transcript available',
              ),
              style: sizing.text.bodySmall.copyWith(
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: widget.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Container(
          margin: EdgeInsets.only(top: sizing.spacingXxs),
          padding: EdgeInsets.all(sizing.spacingSm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(sizing.radiusMd),
            border: Border.all(color: AppColors.border, width: sizing.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.subject_rounded,
                    size: sizing.iconXs,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: sizing.spacingXxs),
                  Text(
                    tr('Transcript'),
                    style: sizing.text.metaLabel.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              SizedBox(height: sizing.spacingXs),
              body,
            ],
          ),
        ),
      ),
    );
  }
}
