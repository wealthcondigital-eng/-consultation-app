import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/chat_message.dart';
import 'voice_note_player.dart';

/// The clip kept from the patient's last consultation with this doctor.
///
/// Deliberately not a bubble: it came from the platform rather than from either
/// person, and it is the one thing in the thread worth finding again.
class ConsultationRecordingCard extends StatelessWidget {
  const ConsultationRecordingCard({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final note = message.voiceNote;
    if (note == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(
          width: sizing.hairline,
          color: AppColors.consultAccent.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                size: sizing.iconXs,
                color: AppColors.primaryVivid,
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Text(
                  message.text ?? tr('Recording of your last consultation'),
                  style: sizing.text.cardTitle.copyWith(
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: sizing.spacingXxs),
          // The player below carries the length, so this only dates it.
          Text(message.dateLabel, style: sizing.text.metaLabel),
          SizedBox(height: sizing.spacingSm),
          VoiceNotePlayer(
            note: note,
            accentColor: AppColors.primaryDeep,
            trackColor: AppColors.consultAccent.border,
            controlBackground: AppColors.primaryDeep,
            controlForeground: Colors.white,
            clockStyle: sizing.text.metaLabel.copyWith(
              color: AppColors.primaryDeep,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (note.transcript case final transcript?) ...[
            SizedBox(height: sizing.spacingSm),
            Container(
              padding: EdgeInsets.all(sizing.tilePadding),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(sizing.radiusMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: sizing.iconXs,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(width: sizing.spacingXs),
                  Expanded(
                    child: Text(transcript, style: sizing.text.bodySmall),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
