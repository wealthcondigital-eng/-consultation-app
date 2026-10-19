import '../../../doctors/domain/entities/doctor.dart';
import 'consultation_mode.dart';

/// Where an instant consultation stands, as the API reports it.
///
/// The states are the server's, not the screen's — both apps poll the same
/// record and render from it, so a status the app invents is a status the other
/// side never sees.
enum LiveConsultationStatus {
  /// Booked for a time in the future. Nobody is waiting and nobody is being
  /// rung — it becomes a call when its time comes and one side joins.
  scheduled,

  /// Filed, no doctor attached yet. Resolves on its own as doctors come online.
  searching,

  /// Offered to one doctor, waiting on them to answer.
  ringing,

  /// The doctor said yes. Both sides now hold the channel.
  accepted,

  /// Someone has joined the room.
  inProgress,

  completed,

  /// The patient withdrew before it connected.
  cancelled,

  /// Nobody took it in time.
  expired;

  static LiveConsultationStatus from(String? value) => switch (value) {
    'scheduled' => LiveConsultationStatus.scheduled,
    'ringing' => LiveConsultationStatus.ringing,
    'accepted' => LiveConsultationStatus.accepted,
    'in_progress' => LiveConsultationStatus.inProgress,
    'completed' => LiveConsultationStatus.completed,
    'cancelled' => LiveConsultationStatus.cancelled,
    'expired' => LiveConsultationStatus.expired,
    _ => LiveConsultationStatus.searching,
  };
}

/// One instant consultation, from request to hang-up.
///
/// The record that puts a patient and a doctor in the same room. Both sides
/// hold one of these and both read the same [channelId] out of it — which is
/// the fix for the two home screens that used to hard-code `consult-room-1`
/// and therefore put every call in the world into one room.
class LiveConsultation {
  const LiveConsultation({
    required this.id,
    required this.status,
    required this.mode,
    required this.channelId,
    required this.peerId,
    required this.isCaller,
    required this.patientName,
    this.isAnonymous = false,
    this.doctor,
    this.fee,
    this.scheduledAt,
    this.concern,
  });

  final String id;
  final LiveConsultationStatus status;
  final ConsultationMode mode;

  /// The WebRTC room. Minted per consultation by the API and never reused.
  final String channelId;

  /// Who *this* device is inside the room.
  ///
  /// The two peers must never send the same value: the signalling store tells
  /// an offer from its own echo by comparing senders, so one shared identity
  /// leaves each side listening to itself and the call never connects.
  final String peerId;

  /// True for the side that creates the offer. Exactly one of the two gets it,
  /// and the API decides which — not whichever screen happened to open first.
  final bool isCaller;

  /// The patient's name, or their alias on an anonymous consultation.
  final String patientName;

  final bool isAnonymous;

  /// Null while still searching; set once a doctor is attached.
  final Doctor? doctor;

  /// What this consultation costs, fixed at the moment the doctor accepted.
  final int? fee;

  /// When a booked consultation is due. Null on an instant one.
  final DateTime? scheduledAt;

  /// What the patient wrote on the way in.
  ///
  /// The doctor reads it before deciding to answer — on an anonymous
  /// consultation it is the only thing they know about the person calling, and
  /// answering or declining with nothing to go on is not a decision.
  final String? concern;

  /// True for a booking rather than a request for a doctor now.
  bool get isScheduled => scheduledAt != null;

  /// True once both sides hold the channel and the call can be opened.
  bool get isConnectable =>
      status == LiveConsultationStatus.accepted ||
      status == LiveConsultationStatus.inProgress;

  /// True while the patient is still waiting on somebody.
  bool get isWaiting =>
      status == LiveConsultationStatus.searching ||
      status == LiveConsultationStatus.ringing;

  /// True when it will never connect — withdrawn, or nobody answered.
  bool get isOver =>
      status == LiveConsultationStatus.completed ||
      status == LiveConsultationStatus.cancelled ||
      status == LiveConsultationStatus.expired;

  /// What to tell the patient when a search ended with no call.
  String? get endedReason => switch (status) {
    LiveConsultationStatus.expired =>
      'No doctor was available. Please try again in a few minutes.',
    LiveConsultationStatus.cancelled => 'The consultation was cancelled.',
    _ => null,
  };
}
