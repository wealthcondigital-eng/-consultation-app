import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../consultation/presentation/widgets/consultation_mode_sheet.dart';
import '../../domain/entities/chat_thread.dart';

/// The thread's header: who the patient is talking to, whether they are on, and
/// the button that starts the call.
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.thread,
    required this.onCall,
    this.onBack,
  });

  final ChatThread thread;

  /// Places the consultation call in the thread's mode.
  final VoidCallback onCall;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final doctor = thread.doctor;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.screenPaddingH,
        vertical: sizing.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: MaterialLocalizations.of(context).backButtonTooltip,
            child: InkWell(
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(sizing.spacingXxs),
                child: Icon(
                  Icons.arrow_back,
                  size: sizing.iconSm,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          SizedBox(width: sizing.spacingXs),
          Container(
            width: sizing.avatarSize,
            height: sizing.avatarSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.avatarSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              size: sizing.iconMd,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: sizing.text.listTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                _Presence(thread: thread),
              ],
            ),
          ),
          SizedBox(width: sizing.spacingXs),
          Semantics(
            button: true,
            label: tr('Start {call}', {'call': thread.mode.callTypeLabel}),
            child: InkWell(
              onTap: onCall,
              customBorder: const CircleBorder(),
              child: Container(
                width: sizing.iconChipSize * 0.8,
                height: sizing.iconChipSize * 0.8,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryDeep,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconForConsultationMode(thread.mode),
                  size: sizing.iconSm,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `Online • Audio Call`, and the alias the patient appears under.
class _Presence extends StatelessWidget {
  const _Presence({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      children: [
        if (thread.isDoctorOnline) ...[
          Container(
            width: sizing.r(6),
            height: sizing.r(6),
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: sizing.spacingXxs),
        ],
        Flexible(
          child: Text(
            [
              if (thread.isDoctorOnline) tr('Online') else tr('Offline'),
              thread.mode.callTypeLabel,
              if (thread.isAnonymous)
                tr('as {name}', {'name': thread.patientDisplayName}),
            ].join(' • '),
            style: sizing.text.metaLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
