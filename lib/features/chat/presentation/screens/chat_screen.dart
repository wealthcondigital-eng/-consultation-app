import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../anonymous/domain/entities/anonymous_session.dart';
import '../../../call/presentation/screens/call_screen.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_thread.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_header.dart';
import '../widgets/consultation_recording_card.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Who the conversation is with, and under what identity.
class ChatArgs {
  const ChatArgs({
    required this.doctor,
    required this.mode,
    this.anonymousSession,
  });

  final Doctor doctor;

  /// How the consultation attached to this thread is held.
  final ConsultationMode mode;

  /// Set when the patient booked anonymously — the thread then shows their
  /// alias and never their real name.
  final AnonymousSession? anonymousSession;

  bool get isAnonymous => anonymousSession != null;
}

/// The conversation with a doctor: the recording kept from the last
/// consultation, everything either side has written, and the composer.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.args});

  final ChatArgs args;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _controller = sl<ChatController>();

  final TextEditingController _composerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.open(
      doctor: widget.args.doctor,
      mode: widget.args.mode,
      anonymousDisplayName: widget.args.anonymousSession?.displayName,
    );
  }

  @override
  void dispose() {
    _composerController.dispose();
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  /// Surfaces whatever the controller could not do — a send that failed, or a
  /// recording too short to be worth posting. A thread that would not open at
  /// all is left to the retry view, which states it in place.
  void _onChanged() {
    final message = _controller.errorMessage;
    if (message == null || _controller.thread == null || !mounted) return;

    _controller.acknowledgeError();
    AppSnackBar.error(context, message);
  }

  void _startCall() {
    Navigator.of(context).pushNamed(
      AppRoutes.call,
      arguments: CallArgs(
        doctor: widget.args.doctor,
        mode: widget.args.mode,
        channelId: _controller.thread?.id ?? 'channel_${widget.args.doctor.id}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        // The thread scrolls itself so the composer stays pinned to the foot.
        scrollable: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final thread = _controller.thread;

            if (_controller.isInitialLoad) {
              return const Center(child: CircularProgressIndicator());
            }

            if (thread == null) {
              return _ThreadError(
                message:
                    _controller.errorMessage ??
                    tr('This conversation is not available.'),
                onRetry: () => _controller.open(
                  doctor: widget.args.doctor,
                  mode: widget.args.mode,
                  anonymousDisplayName:
                      widget.args.anonymousSession?.displayName,
                ),
              );
            }

            return Column(
              children: [
                ChatHeader(thread: thread, onCall: _startCall),
                if (thread.isAnonymous) _AnonymousStrip(thread: thread),
                Expanded(child: _Messages(messages: _controller.messages)),
                ChatComposer(
                  controller: _composerController,
                  enabled: !_controller.isLoading,
                  isRecording: _controller.isRecording,
                  recordingLabel: _controller.recordingLabel,
                  recordingWaveform: _controller.recordingWaveform,
                  onSendText: _controller.sendText,
                  onStartRecording: _controller.startRecording,
                  onSendRecording: _controller.stopRecordingAndSend,
                  onCancelRecording: _controller.cancelRecording,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Messages extends StatelessWidget {
  const _Messages({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: sizing.screenPadding,
          child: Text(
            tr('Say hello — your doctor will see this before the call.'),
            style: sizing.text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Reversed so the newest message sits at the bottom and the list opens
    // there, which is where a conversation is read from.
    return ListView.separated(
      reverse: true,
      padding: EdgeInsets.symmetric(
        horizontal: sizing.screenPaddingH,
        vertical: sizing.spacingMd,
      ),
      itemCount: messages.length,
      separatorBuilder: (_, _) => SizedBox(height: sizing.spacingSm),
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        // Keyed by message so playback and layout state follow the message
        // rather than its position in the list.
        final key = ValueKey(message.id);

        return message.isConsultationRecording
            ? ConsultationRecordingCard(key: key, message: message)
            : ChatBubble(key: key, message: message);
      },
    );
  }
}

/// The standing reminder that the doctor cannot see who the patient is.
class _AnonymousStrip extends StatelessWidget {
  const _AnonymousStrip({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: sizing.screenPaddingH,
        vertical: sizing.spacingXs,
      ),
      color: AppColors.badgeSurface,
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: sizing.iconXs,
            color: AppColors.primaryDeep,
          ),
          SizedBox(width: sizing.spacingXs),
          Expanded(
            child: Text(
              tr('You appear as {name}. Your real identity is never shared.', {
                'name': thread.patientDisplayName,
              }),
              style: sizing.text.metaLabel.copyWith(
                color: AppColors.primaryDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadError extends StatelessWidget {
  const _ThreadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Center(
      child: Padding(
        padding: sizing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: sizing.r(40),
              color: AppColors.textTertiary,
            ),
            SizedBox(height: sizing.spacingSm),
            Text(
              tr(message),
              style: sizing.text.bodySmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: sizing.spacingXs),
            TextButton(
              onPressed: onRetry,
              child: Text(tr('Retry'), style: sizing.text.sectionAction),
            ),
          ],
        ),
      ),
    );
  }
}
