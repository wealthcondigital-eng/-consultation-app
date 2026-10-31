import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/device/call_device.dart';
import '../../../../core/device/call_permissions.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../consultation/domain/entities/live_consultation.dart';
import '../../../consultation/presentation/screens/consultation_feedback_screen.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/call_session.dart';
import '../controllers/active_call.dart';
import '../controllers/call_controller.dart';
import '../widgets/call_controls_bar.dart';

class CallArgs {
  const CallArgs({
    required this.doctor,
    required this.mode,
    required this.channelId,
    this.consultationId,
    this.peerId = 'self',
    this.isCaller = true,
    this.peerName,
    this.peerSubtitle,
    this.recordingConsent = false,
    this.isAnonymous = false,
  });

  /// From a brokered consultation, which is where every real call comes from:
  /// the API named the room, said who this device is inside it, and decided
  /// which of the two dials.
  factory CallArgs.fromConsultation(LiveConsultation consultation) {
    return CallArgs(
      doctor: consultation.doctor ?? _unknownDoctor,
      mode: consultation.mode,
      channelId: consultation.channelId,
      consultationId: consultation.id,
      peerId: consultation.peerId,
      isCaller: consultation.isCaller,
      // Whoever is on the *other* end. The patient is calling a doctor, and
      // the doctor is talking to a patient — one screen serves both, so it
      // cannot label itself with the doctor's name either way. It did, which
      // left a doctor looking at their own name for the length of the call.
      //
      // `isCaller` is the API's answer to "which end is this", and the patient
      // is the side that dials — see `ConsultationsService.toJson`.
      peerName: consultation.isCaller
          ? consultation.doctor?.name
          : consultation.patientName,
      // The line under the name. A doctor's speciality is worth showing; a
      // patient has no title, so the doctor's side is told what kind of caller
      // this is rather than being left with a blank line.
      peerSubtitle: consultation.isCaller
          ? consultation.doctor?.speciality
          : consultation.isAnonymous
          ? 'Anonymous patient'
          : 'Patient',
      recordingConsent: consultation.recordingConsent,
      isAnonymous: consultation.isAnonymous,
    );
  }

  /// Stands in on the doctor's side, where the consultation carries the doctor
  /// themselves and the call screen is showing them the patient. The call runs
  /// on the channel, not on this.
  static const Doctor _unknownDoctor = Doctor(
    id: 'unknown',
    name: 'Consultation',
    speciality: '',
    yearsOfExperience: 0,
    rating: 0,
    consultationFee: 0,
  );

  final Doctor doctor;
  final ConsultationMode mode;
  final String channelId;

  /// The consultation being had, when the call came from the instant flow.
  /// Null for a call opened outside it — there is then no record to close.
  final String? consultationId;

  /// Who this device is in the room. Must differ between the two peers.
  final String peerId;

  /// True for the side that creates the offer.
  final bool isCaller;

  /// Who is on the other end of this call, as this device should label them.
  /// Falls back to the doctor for a call opened outside the instant flow.
  final String? peerName;

  /// One line under [displayName] — the doctor's speciality on the patient's
  /// side, and what kind of caller this is on the doctor's.
  final String? peerSubtitle;

  /// The patient agreed to this consultation being recorded.
  final bool recordingConsent;

  final bool isAnonymous;

  /// True when this consultation is recorded at all — consented, attached to
  /// a record, and never anonymous.
  bool get isRecorded =>
      recordingConsent && !isAnonymous && consultationId != null;

  /// True when *this* phone does the recording: the patient's, which is the
  /// side that dials. The doctor's phone only shows the badge.
  bool get recordsHere => isRecorded && isCaller;

  /// The name to put at the top of the call.
  String get displayName {
    final name = (peerName ?? doctor.name).trim();
    return name.isEmpty ? tr('Consultation') : name;
  }

  /// The line under it. Empty rather than null when there is nothing to say, so
  /// the layout does not shift between the two sides of the same call.
  String get displaySubtitle => tr((peerSubtitle ?? doctor.speciality).trim());

  /// The avatar's fallback: one or two letters from [displayName].
  ///
  /// Derived from the **peer's** name, which is the whole point — the audio
  /// screen used to draw the doctor's own initial on the doctor's own phone.
  String get peerInitials => initialsOf(displayName, fallback: 'C');
}

class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.args});

  final CallArgs args;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  /// The call outlives this screen — see [ActiveCall]. Opening the screen for
  /// the consultation already under way re-attaches to it.
  late final ActiveCall _active = sl<ActiveCall>();
  late final CallController _controller = _active.attach(widget.args);

  /// True once the screen has navigated away, so the controller's later
  /// notifications cannot pop the dashboard back off.
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _active.screenOpened();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _inBackground = true;
        _syncProximity();
      },
      onShow: () {
        _inBackground = false;
        _syncProximity();
      },
    );
    // After the first frame: the permission prompt is a dialog, and a dialog
    // cannot open while this screen is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Back to a call already under way: nothing to start, only the screen
      // to keep awake.
      if (_active.isStarted(_controller)) {
        WakelockPlus.enable().catchError((Object _) {});
        _syncProximity();
        return;
      }
      _start();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // Released whichever way the screen closes — hung up, backed out, or the
    // other side dropped. A call that leaves the wakelock on drains the phone
    // for the rest of the day.
    WakelockPlus.disable().catchError((Object _) {});

    if (_proximityOn) CallDevice.setProximityScreenOff(false);

    _controller.removeListener(_onChanged);
    // The call is not this screen's to end: a live one carries on, with the
    // ongoing-call bar as the way back. Only a call that never started is let
    // go here.
    _active.screenClosed();
    _active.discardIfNotStarted(_controller);
    super.dispose();
  }

  /// Set when the microphone (or camera) was refused, which the screen shows
  /// in place of the call, with a way to allow it.
  String? _permissionError;

  Future<void> _start() async {
    // A consultation is minutes of looking at the screen without touching it,
    // which is exactly what the display timeout is waiting for. Without this the
    // screen sleeps mid-sentence and the video freezes for whoever is talking.
    WakelockPlus.enable().catchError((Object error) {
      // Not worth failing a call over. The screen may sleep; the call does not.
      debugPrint('Could not keep the screen awake: $error');
    });

    // Asked for before anything opens, on every path into a call — instant,
    // scheduled, anonymous, a rejoin, and a doctor answering from the lock
    // screen. See [CallPermissions].
    final isVideo = widget.args.mode == ConsultationMode.video;
    final allowed = await CallPermissions.ensure(context, video: isVideo);
    if (!mounted) return;

    if (!allowed) {
      setState(() {
        _permissionError = isVideo
            ? tr('Allow camera and microphone access to start the call.')
            : tr('Allow microphone access to start the call.');
      });
      return;
    }
    if (_permissionError != null) setState(() => _permissionError = null);

    _controller.initCall(
      doctor: widget.args.doctor,
      mode: widget.args.mode,
      channelId: widget.args.channelId,
      consultationId: widget.args.consultationId,
      peerId: widget.args.peerId,
      isCaller: widget.args.isCaller,
      record: widget.args.recordsHere,
    );
  }

  /// The red badge. On the patient's phone it follows the recorder itself;
  /// on the doctor's it follows the consultation, from the moment the call is
  /// live — the doctor cannot see the patient's recorder, and should know it
  /// is on all the same.
  bool get _showRecordingBadge {
    if (widget.args.recordsHere) return _controller.isRecording;
    return widget.args.isRecorded &&
        (_controller.state == CallState.connected ||
            _controller.state == CallState.reconnecting);
  }

  /// Whether the screen is currently set to go dark against the ear.
  bool _proximityOn = false;

  /// A voice call on the earpiece is held to the ear, so the screen goes dark
  /// there the way the phone's own dialler does. Off on the speaker, off for
  /// video, and off as soon as the call is over.
  /// True while the app is behind another one — after back, during a call.
  bool _inBackground = false;

  late final AppLifecycleListener _lifecycle;

  void _syncProximity() {
    final state = _controller.state;
    final wanted =
        mounted &&
        // Never while the call is in the background: the sensor would
        // blank the screen over whatever other app is in use.
        !_inBackground &&
        widget.args.mode == ConsultationMode.audio &&
        !_controller.isSpeakerOn &&
        (state == CallState.connecting ||
            state == CallState.connected ||
            state == CallState.reconnecting);

    if (wanted == _proximityOn) return;
    _proximityOn = wanted;
    CallDevice.setProximityScreenOff(wanted);
  }

  void _onChanged() {
    // The background service and the lock-screen display follow the call,
    // not this screen — [ActiveCall] holds them.
    _syncProximity();

    if (!mounted || _controller.state != CallState.ended || _left) return;

    // Once. The controller notifies again as the teardown settles, and a second
    // navigation would pop the dashboard straight back off.
    _left = true;

    // The patient is asked what they made of it, once, at the only moment they
    // will ever be willing to answer: the call has just ended and they are
    // still holding the phone. The review screen existed but nothing reached
    // it from a real consultation — it was shown when a *doctor was found*,
    // before a word had been said, and it wrote nothing anywhere.
    //
    // Only the patient, and only for a consultation there is a record to rate.
    // The doctor goes straight to their dashboard: the next call is the thing
    // in front of them.
    if (widget.args.isCaller && widget.args.consultationId != null) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.consultationFeedback,
        ModalRoute.withName(AppRoutes.home),
        arguments: ConsultationFeedbackArgs(
          consultationId: widget.args.consultationId!,
          doctor: widget.args.doctor,
          mode: widget.args.mode,
          durationInSeconds: _controller.durationInSeconds,
        ),
      );
      return;
    }

    // Back to the dashboard, not `pop`. A call is reached through a stack —
    // options, the search, the listing, the call — and popping put the patient
    // back in the middle of the flow that started it, staring at a doctor list
    // for a consultation they had just finished. Ending a call belongs at home,
    // however it ended: hung up here, hung up by the other side, or dropped.
    Navigator.of(context).pushNamedAndRemoveUntil(
      // Whose dashboard depends on which side of the call this is, and the
      // consultation already says: the patient is the caller.
      widget.args.isCaller ? AppRoutes.home : AppRoutes.doctorHome,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final isVideoCall = widget.args.mode == ConsultationMode.video;

    // The system back gesture is a hang-up, the same as the back arrow. It
    // used to pop the screen with the call still running behind it — camera,
    // microphone and connection all open — and the next call, usually a
    // rejoin, started on top of that one.
    // Back does **not** hang up. It sends the app to the background and the
    // consultation carries on — microphone, camera and connection held by the
    // call's foreground service, with its "Consultation in progress"
    // notification as the way back — exactly as a phone call behaves. Only the
    // red button ends a call. (Back used to hang up, so a patient who reached
    // for their home screen mid-consultation cut the doctor off.)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _backPressed();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.black,
        ),
        child: ResponsivePage(
          backgroundColor: Colors.black,
          scrollable: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final state = _controller.state;

              if (_permissionError case final message?) {
                return _CallErrorView(
                  title: tr('Permission needed'),
                  errorMessage: message,
                  retryLabel: tr('Allow'),
                  // Asks again, or opens Settings when the phone will not.
                  onRetry: _start,
                  onClose: _close,
                );
              }

              if (state == CallState.failed) {
                return _CallErrorView(
                  errorMessage:
                      _controller.session?.errorMessage ??
                      tr('Call connection failed.'),
                  // The whole of the args, not just the doctor and the mode: a
                  // retry that dropped the consultation would have nothing to
                  // rejoin, and would fail for a different reason than the one
                  // being retried.
                  onRetry: _start,
                  onClose: _close,
                );
              }

              return Stack(
                children: [
                  // 1. Background Video or Audio Avatar
                  if (isVideoCall) ...[
                    Positioned.fill(
                      child: RTCVideoView(
                        _controller.remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                    // Over the remote view until media is actually flowing. The
                    // remote renderer used to be pointed at this device's own
                    // camera while connecting, so a call that never joined looked
                    // exactly like one that had — you were watching yourself.
                    if (state != CallState.connected)
                      Positioned.fill(
                        child: _ConnectingOverlay(
                          peerName: widget.args.displayName,
                          state: state,
                        ),
                      ),
                  ] else
                    // The **peer**, not the doctor. This used to be handed the
                    // consultation's doctor and rendered their name and
                    // speciality on both phones, so a doctor on an audio call
                    // spent it looking at their own name in a 24pt font — and
                    // the patient saw the right name only by coincidence.
                    _AudioCallAvatarBackground(
                      name: widget.args.displayName,
                      subtitle: widget.args.displaySubtitle,
                      initials: widget.args.peerInitials,
                      state: state,
                      duration: _controller.formattedDuration,
                      isMuted: _controller.isAudioMuted,
                      isSpeakerOn: _controller.isSpeakerOn,
                    ),

                  // 2. Floating Local PIP Video Preview (for Video mode)
                  if (isVideoCall && !_controller.isVideoMuted)
                    Positioned(
                      top: sizing.spacingXl + sizing.r(50),
                      right: sizing.screenPaddingH,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(sizing.r(16)),
                        child: Container(
                          width: sizing.r(110),
                          height: sizing.r(160),
                          color: Colors.grey[900],
                          child: RTCVideoView(
                            _controller.localRenderer,
                            mirror: _controller.isFrontCamera,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                        ),
                      ),
                    ),

                  // 3. Top Call Info Header Bar
                  Positioned(
                    top: sizing.spacingMd,
                    left: sizing.screenPaddingH,
                    right: sizing.screenPaddingH,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                          // The same as the system back: the call keeps
                          // running in the background. See [_backPressed].
                          onPressed: _backPressed,
                        ),
                        SizedBox(width: sizing.spacingXs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.args.displayName,
                                style: sizing.text.brandTitle.copyWith(
                                  color: Colors.white,
                                  fontSize: sizing.sp(18),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                state == CallState.connected
                                    ? _controller.formattedDuration
                                    : _statusText(state),
                                style: sizing.text.metaLabel.copyWith(
                                  color: state == CallState.connected
                                      ? AppColors.success
                                      : Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showRecordingBadge) const _RecordingBadge(),
                      ],
                    ),
                  ),

                  // 4. Bottom Controls Bar
                  Positioned(
                    bottom: sizing.spacingXl,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CallControlsBar(
                        isAudioMuted: _controller.isAudioMuted,
                        isVideoMuted: _controller.isVideoMuted,
                        isSpeakerOn: _controller.isSpeakerOn,
                        isFrontCamera: _controller.isFrontCamera,
                        isVideoCall: isVideoCall,
                        onToggleAudio: _controller.toggleAudioMute,
                        onToggleVideo: _controller.toggleVideoMute,
                        onSwitchCamera: _controller.switchCamera,
                        onToggleSpeaker: _controller.toggleSpeaker,
                        onEndCall: _controller.endCall,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Back, from the gesture or the arrow.
  ///
  /// A call that is under way — connecting, connected or reconnecting — keeps
  /// going: the app is sent to the background and the consultation continues
  /// there. One that never got going (still asking for permission, failed, or
  /// already over) has nothing to keep, so the screen simply closes.
  void _backPressed() {
    final state = _controller.state;
    final isLive =
        _permissionError == null &&
        (state == CallState.connecting ||
            state == CallState.connected ||
            state == CallState.reconnecting);

    if (!isLive) {
      _close();
      return;
    }

    // Live: leave the screen, keep the call. The person lands on their
    // dashboard and can go anywhere in the app; the ongoing-call bar across
    // the top shows the timer and brings them back here with one tap.
    final navigator = Navigator.of(context);
    final home = widget.args.isCaller ? AppRoutes.home : AppRoutes.doctorHome;

    var foundHome = false;
    navigator.popUntil((route) {
      if (route.settings.name == home) {
        foundHome = true;
        return true;
      }
      return route.isFirst;
    });
    // The call was the bottom of the stack — opened from a ringing screen on
    // a phone that was locked, say — so there is no dashboard under it yet.
    if (!foundHome) navigator.pushNamed(home);
  }

  /// Leaves a call that never got going — refused, or failed. The call itself
  /// is torn down with the controller as the screen goes.
  void _close() {
    if (_left) return;
    _left = true;

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    // Opened as the only route — from a ringing screen, say — so there is
    // nothing under it to go back to. Home, for whichever side this is.
    navigator.pushNamedAndRemoveUntil(
      widget.args.isCaller ? AppRoutes.home : AppRoutes.doctorHome,
      (route) => false,
    );
  }

  String _statusText(CallState state) {
    switch (state) {
      case CallState.initializing:
        return tr('Initializing media...');
      case CallState.connecting:
        // Not "connecting to doctor". One screen serves both ends of the call,
        // and a doctor is not connecting to a doctor.
        return tr('Connecting…');
      case CallState.reconnecting:
        return tr('Reconnecting...');
      case CallState.connected:
        return tr('Connected');
      case CallState.ended:
        return tr('Call ended');
      case CallState.failed:
        return tr('Call failed');
    }
  }
}

/// The audio call's whole screen: whoever is on the other end, and the timer.
///
/// Takes a name and initials rather than a [Doctor], because on the doctor's
/// phone the other end is a *patient* and there is no `Doctor` that describes
/// them. Being handed the consultation's doctor is exactly the bug this
/// replaced — both sides rendered the doctor.
class _AudioCallAvatarBackground extends StatelessWidget {
  const _AudioCallAvatarBackground({
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.state,
    required this.duration,
    required this.isMuted,
    required this.isSpeakerOn,
  });

  final String name;

  /// Empty when there is nothing to say under the name.
  final String subtitle;

  final String initials;
  final CallState state;
  final String duration;

  /// Both are already on the controls bar, and both are restated here.
  ///
  /// A voice call is the one screen people look away from: it goes to an ear,
  /// or face down on a desk. Coming back to it and finding out whether you are
  /// still muted should not mean reading a row of small circles, and "why can
  /// they not hear me" is the single most common thing to go wrong on one.
  final bool isMuted;
  final bool isSpeakerOn;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final isConnected = state == CallState.connected;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        // The brand teal into near-black, rather than a flat slate. A voice
        // call is the app's most-looked-at screen and was the only one with no
        // colour on it at all.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryDeep, AppColors.inkDeep],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The peer's avatar. It pulses while the call is being set up and
          // settles once media is flowing — which is the difference between
          // "ringing" and "connected" stated without words.
          _PulsingRing(
            isPulsing: !isConnected && state != CallState.ended,
            child: CircleAvatar(
              radius: sizing.r(64),
              backgroundColor: AppColors.primary,
              child: Text(
                initials,
                style: sizing.text.brandTitle.copyWith(
                  color: Colors.white,
                  // A shade smaller than before, because these are now two
                  // letters rather than one.
                  fontSize: sizing.sp(40),
                ),
              ),
            ),
          ),
          SizedBox(height: sizing.spacingLg),

          // Whoever is on the other end, and one line about them.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sizing.screenPaddingH),
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: sizing.text.brandTitle.copyWith(
                color: Colors.white,
                fontSize: sizing.sp(24),
              ),
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            SizedBox(height: sizing.spacingXs),
            Text(
              subtitle,
              style: sizing.text.bodySmall.copyWith(color: Colors.white70),
            ),
          ],
          SizedBox(height: sizing.spacingLg),

          // What is actually happening. This said "Calling..." for every state
          // that was not connected, so a call that had failed to negotiate, one
          // that had dropped and was reconnecting, and one that had already
          // ended all looked identical — and all three looked like a phone
          // ringing somewhere.
          _AudioStatusBadge(state: state, duration: duration),

          // Mute and route, restated where they can be seen from across a room.
          if (isMuted || isSpeakerOn) ...[
            SizedBox(height: sizing.spacingMd),
            Wrap(
              spacing: sizing.spacingXs,
              alignment: WrapAlignment.center,
              children: [
                if (isMuted)
                  _AudioStatePill(
                    icon: Icons.mic_off_rounded,
                    label: 'Your mic is off',
                    tone: AppColors.danger,
                  ),
                if (isSpeakerOn)
                  _AudioStatePill(
                    icon: Icons.volume_up_rounded,
                    label: 'Speaker',
                    tone: AppColors.primarySoft,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// `02:14` once media is flowing, and the honest name of every other state.
class _AudioStatusBadge extends StatelessWidget {
  const _AudioStatusBadge({required this.state, required this.duration});

  final CallState state;
  final String duration;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final (label, tone) = switch (state) {
      CallState.connected => (duration, AppColors.success),
      CallState.initializing => (tr('Starting…'), Colors.white),
      CallState.connecting => (tr('Ringing…'), Colors.white),
      CallState.reconnecting => (tr('Reconnecting…'), AppColors.warning),
      CallState.ended => (tr('Call ended'), Colors.white70),
      CallState.failed => (tr('Could not connect'), AppColors.danger),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingMd,
        vertical: sizing.spacingXs,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(sizing.r(20)),
        border: Border.all(color: tone.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: sizing.text.metaLabel.copyWith(
          color: tone,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A small caption on the audio call: what is muted, where the sound is going.
class _AudioStatePill extends StatelessWidget {
  const _AudioStatePill({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingSm,
        vertical: sizing.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(sizing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: sizing.iconXs * 0.85, color: tone),
          SizedBox(width: sizing.spacingXxs),
          Text(
            tr(label),
            style: sizing.text.metaLabel.copyWith(
              color: tone,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "● Recording", top right, on both phones while the call is being recorded.
///
/// Small and steady rather than blinking: it is there so nobody is recorded
/// without seeing it, not to compete with the person they are talking to.
/// "● Recording", with the dot blinking — on both phones, so neither side
/// can miss that the call is being kept.
class _RecordingBadge extends StatefulWidget {
  const _RecordingBadge();

  @override
  State<_RecordingBadge> createState() => _RecordingBadgeState();
}

class _RecordingBadgeState extends State<_RecordingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingSm,
        vertical: sizing.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(sizing.radiusPill),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(
              begin: 1,
              end: 0.15,
            ).animate(CurvedAnimation(parent: _blink, curve: Curves.easeInOut)),
            child: Container(
              width: sizing.r(9),
              height: sizing.r(9),
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.6),
                    blurRadius: sizing.r(6),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: sizing.spacingXs),
          Text(
            tr('Recording'),
            style: sizing.text.metaLabel.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A ring that breathes while a call is being set up, and stops once it is.
///
/// The only moving thing on a voice call. Without it there is no difference on
/// screen between a call that is connecting and one that has silently died —
/// the timer does not start either way.
class _PulsingRing extends StatefulWidget {
  const _PulsingRing({required this.isPulsing, required this.child});

  final bool isPulsing;
  final Widget child;

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPulsing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing == oldWidget.isPulsing) return;

    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    } else {
      // Stopped and wound back, so the ring settles at its resting size rather
      // than freezing wherever the animation happened to be.
      _controller
        ..stop()
        ..animateTo(0, duration: const Duration(milliseconds: 250));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        return Container(
          padding: EdgeInsets.all(sizing.spacingSm + sizing.r(6) * t),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45 - 0.25 * t),
              width: sizing.r(3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 28 + 16 * t,
                spreadRadius: 4 + 6 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Covers the remote view until the other side's video actually arrives.
///
/// Names what is happening rather than showing black, because the two states it
/// stands in for feel identical otherwise: waiting on a handshake and waiting on
/// a person who has walked away from their phone.
class _ConnectingOverlay extends StatelessWidget {
  const _ConnectingOverlay({required this.peerName, required this.state});

  final String peerName;
  final CallState state;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return ColoredBox(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white54),
          SizedBox(height: sizing.spacingXl),
          Text(switch (state) {
            CallState.reconnecting => tr('Reconnecting…'),
            CallState.ended => tr('Call ended'),
            _ => tr('Connecting…'),
          }, style: sizing.text.cardTitle.copyWith(color: Colors.white)),
          SizedBox(height: sizing.spacingXs),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sizing.screenPaddingH),
            child: Text(
              tr('Waiting for {name} to join.', {'name': peerName}),
              textAlign: TextAlign.center,
              style: sizing.text.bodySmall.copyWith(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallErrorView extends StatelessWidget {
  const _CallErrorView({
    required this.errorMessage,
    required this.onRetry,
    required this.onClose,
    this.title,
    this.retryLabel,
  });

  final String errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  /// "Call Failed" unless a refused permission says otherwise.
  final String? title;
  final String? retryLabel;

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
              Icons.error_outline_rounded,
              size: sizing.r(48),
              color: AppColors.danger,
            ),
            SizedBox(height: sizing.spacingMd),
            Text(
              title ?? tr('Call Failed'),
              style: sizing.text.brandTitle.copyWith(color: Colors.white),
            ),
            SizedBox(height: sizing.spacingXs),
            Text(
              tr(errorMessage),
              style: sizing.text.bodySmall.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: sizing.spacingLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  child: Text(tr('Close')),
                ),
                SizedBox(width: sizing.spacingMd),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(retryLabel ?? tr('Retry Call')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
