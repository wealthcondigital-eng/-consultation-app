import '../../../../core/format/app_date_format.dart';
import 'voice_note.dart';

/// Who put a message in the thread.
enum ChatAuthor {
  patient,
  doctor,

  /// The platform itself — a consultation recording filed into the thread, or
  /// a privacy notice. Rendered as a full-width card, not as a bubble.
  system,
}

/// How far a message the patient sent has got.
enum ChatMessageStatus { sending, sent, failed }

/// One entry in a patient–doctor thread: a line of text, a voice note, or a
/// recording the platform filed after a consultation.
class ChatMessage {
  const ChatMessage._({
    required this.id,
    required this.author,
    required this.sentAt,
    this.text,
    this.voiceNote,
    this.status = ChatMessageStatus.sent,
    this.isConsultationRecording = false,
  });

  const ChatMessage.text({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required String body,
    ChatMessageStatus status = ChatMessageStatus.sent,
  }) : this._(
         id: id,
         author: author,
         sentAt: sentAt,
         text: body,
         status: status,
       );

  const ChatMessage.voice({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required VoiceNote note,
    ChatMessageStatus status = ChatMessageStatus.sent,
  }) : this._(
         id: id,
         author: author,
         sentAt: sentAt,
         voiceNote: note,
         status: status,
       );

  /// The audio kept from a consultation the patient already had with this
  /// doctor, filed into the thread so it is to hand next time they talk.
  const ChatMessage.consultationRecording({
    required String id,
    required DateTime sentAt,
    required VoiceNote note,
    String? summary,
  }) : this._(
         id: id,
         author: ChatAuthor.system,
         sentAt: sentAt,
         voiceNote: note,
         text: summary,
         isConsultationRecording: true,
       );

  final String id;
  final ChatAuthor author;
  final DateTime sentAt;

  /// The body of a text message, or the caption on a recording card.
  final String? text;

  /// Set when this message is audio rather than text.
  final VoiceNote? voiceNote;

  final ChatMessageStatus status;

  /// True for the clip kept from an earlier consultation.
  final bool isConsultationRecording;

  bool get isVoiceNote => voiceNote != null;
  bool get isFromPatient => author == ChatAuthor.patient;
  bool get isFromSystem => author == ChatAuthor.system;
  bool get isPending => status == ChatMessageStatus.sending;
  bool get hasFailed => status == ChatMessageStatus.failed;

  /// `9:41 am`
  String get timeLabel =>
      AppDateFormat.clockTime(sentAt, lowercaseMeridiem: true);

  /// `12 Aug` — how the recording card dates the earlier consultation.
  String get dateLabel => AppDateFormat.dayMonth(sentAt);

  ChatMessage copyWith({String? id, ChatMessageStatus? status}) {
    return ChatMessage._(
      id: id ?? this.id,
      author: author,
      sentAt: sentAt,
      text: text,
      voiceNote: voiceNote,
      status: status ?? this.status,
      isConsultationRecording: isConsultationRecording,
    );
  }
}
