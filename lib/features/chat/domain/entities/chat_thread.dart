import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import 'chat_message.dart';

/// A conversation between one patient and one doctor.
class ChatThread {
  const ChatThread({
    required this.id,
    required this.doctor,
    required this.patientDisplayName,
    required this.mode,
    this.messages = const [],
    this.isAnonymous = false,
    this.isDoctorOnline = false,
  });

  final String id;
  final Doctor doctor;

  /// How the patient appears to the doctor — their alias in an anonymous
  /// thread, their own name otherwise.
  final String patientDisplayName;

  /// How the consultation attached to this thread is held.
  final ConsultationMode mode;

  /// Oldest first.
  final List<ChatMessage> messages;

  final bool isAnonymous;

  /// True when the doctor can pick up right now.
  final bool isDoctorOnline;

  /// The most recent clip kept from an earlier consultation, if any.
  ChatMessage? get consultationRecording {
    for (final message in messages.reversed) {
      if (message.isConsultationRecording) return message;
    }
    return null;
  }

  ChatThread copyWith({List<ChatMessage>? messages, bool? isDoctorOnline}) {
    return ChatThread(
      id: id,
      doctor: doctor,
      patientDisplayName: patientDisplayName,
      mode: mode,
      messages: messages ?? this.messages,
      isAnonymous: isAnonymous,
      isDoctorOnline: isDoctorOnline ?? this.isDoctorOnline,
    );
  }
}
