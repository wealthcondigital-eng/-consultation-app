import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';

enum CallState {
  initializing,
  connecting,
  connected,
  reconnecting,
  ended,
  failed,
}

/// Active 1-to-1 WebRTC call session state entity.
class CallSession {
  const CallSession({
    required this.channelId,
    required this.doctor,
    required this.mode,
    this.consultationId,
    this.peerId = 'self',
    this.isCaller = true,
    this.status = CallState.initializing,
    this.isAudioMuted = false,
    this.isVideoMuted = false,
    bool? isSpeakerOn,
    this.isFrontCamera = true,
    this.errorMessage,
    this.durationInSeconds = 0,
  }) : isSpeakerOn = isSpeakerOn ?? mode == ConsultationMode.video;

  final String channelId;
  final Doctor doctor;
  final ConsultationMode mode;

  /// The consultation this call belongs to, when it came from the instant
  /// flow. Null for a call opened outside it — hanging up then has no record to
  /// close.
  final String? consultationId;

  /// Who this device is inside the room.
  ///
  /// The signalling store tells an offer from its own echo by comparing
  /// senders, so the two peers must never send the same value. Both sides used
  /// to send the doctor's id, which meant each was filtering out the other's
  /// SDP as its own — the call could only connect by accident. The API hands
  /// each side a distinct value now.
  final String peerId;

  /// True for the side that creates the offer.
  ///
  /// Decided by the API, not by racing: both peers used to ask "is there an
  /// offer yet?" and become the caller if not, so two devices starting together
  /// both offered and neither answered.
  final bool isCaller;

  final CallState status;
  final bool isAudioMuted;
  final bool isVideoMuted;

  /// Which output the call is coming out of.
  ///
  /// Defaults **by call type** rather than always to true. A video call is held
  /// at arm's length and belongs on the speaker; a voice call is held to the
  /// ear and does not, which is how every phone in the world behaves and what
  /// anyone taking a medical call in a waiting room expects. The old flat
  /// default also made the first tap of the speaker button appear to do
  /// nothing, because it was switching away from a state the phone had never
  /// actually been put into.
  final bool isSpeakerOn;
  final bool isFrontCamera;
  final String? errorMessage;
  final int durationInSeconds;

  CallSession copyWith({
    String? channelId,
    Doctor? doctor,
    ConsultationMode? mode,
    CallState? status,
    bool? isAudioMuted,
    bool? isVideoMuted,
    bool? isSpeakerOn,
    bool? isFrontCamera,
    String? errorMessage,
    int? durationInSeconds,
  }) {
    return CallSession(
      channelId: channelId ?? this.channelId,
      doctor: doctor ?? this.doctor,
      mode: mode ?? this.mode,
      consultationId: consultationId,
      peerId: peerId,
      isCaller: isCaller,
      status: status ?? this.status,
      isAudioMuted: isAudioMuted ?? this.isAudioMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      errorMessage: errorMessage ?? this.errorMessage,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
    );
  }
}
