import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/chat_message.dart';
import 'voice_note_player.dart';

/// One message in the thread: the patient's on the right in brand blue, the
/// doctor's on the left in white.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final isMine = message.isFromPatient;
    final corner = Radius.circular(sizing.radiusLg);
    final tail = Radius.circular(sizing.radiusXs);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        // A bubble stops well short of the far edge so the thread still reads
        // as a conversation with two sides.
        constraints: BoxConstraints(maxWidth: sizing.w(280)),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: sizing.spacingSm,
            vertical: sizing.spacingXs + 2,
          ),
          decoration: BoxDecoration(
            color: isMine ? AppColors.primaryDeep : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: corner,
              topRight: corner,
              bottomLeft: isMine ? corner : tail,
              bottomRight: isMine ? tail : corner,
            ),
            border: isMine
                ? null
                : Border.all(width: sizing.hairline, color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.voiceNote case final note?)
                SizedBox(
                  width: sizing.w(232),
                  child: VoiceNotePlayer(
                    note: note,
                    accentColor: isMine ? Colors.white : AppColors.primaryDeep,
                    trackColor: isMine
                        ? Colors.white.withValues(alpha: 0.4)
                        : AppColors.border,
                    controlBackground: isMine
                        ? Colors.white.withValues(alpha: 0.18)
                        : AppColors.primarySurface,
                    controlForeground: isMine
                        ? Colors.white
                        : AppColors.primaryDeep,
                    clockStyle: sizing.text.metaLabel.copyWith(
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.textSecondary,
                    ),
                  ),
                )
              else if (message.text case final text?)
                Text(
                  text,
                  style: sizing.text.cardBody.copyWith(
                    color: isMine ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              SizedBox(height: sizing.spacingXxs),
              _MessageMeta(message: message, isMine: isMine),
            ],
          ),
        ),
      ),
    );
  }
}

/// Timestamp, plus how far a sent message has got.
class _MessageMeta extends StatelessWidget {
  const _MessageMeta({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final color = isMine
        ? Colors.white.withValues(alpha: 0.75)
        : AppColors.textTertiary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.timeLabel,
          style: sizing.text.metaLabel.copyWith(color: color),
        ),
        if (isMine) ...[
          SizedBox(width: sizing.spacingXxs),
          if (message.hasFailed)
            Text(
              tr('Not sent'),
              style: sizing.text.metaLabel.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Icon(
              message.isPending
                  ? Icons.schedule_rounded
                  : Icons.done_all_rounded,
              size: sizing.iconXs * 0.75,
              color: color,
            ),
        ],
      ],
    );
  }
}
