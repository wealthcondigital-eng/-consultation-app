import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/l10n/tr.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_thread.dart';
import '../../domain/entities/voice_note.dart';
import '../../domain/usecases/open_chat_thread.dart';
import '../../domain/usecases/send_chat_message.dart';

/// Presentation state for the conversation with a doctor.
///
/// Sends are optimistic: the message appears immediately as pending and is
/// replaced by the stored one, so the thread never stalls on the network.
class ChatController extends ChangeNotifier {
  ChatController(this._openChatThread, this._sendChatMessage);

  final OpenChatThread _openChatThread;
  final SendChatMessage _sendChatMessage;

  /// How often the recorder reports a new amplitude.
  static const Duration _recordingTick = Duration(milliseconds: 120);

  /// Nobody dictates a useful voice note for longer than this.
  static const Duration maxRecordingDuration = Duration(minutes: 5);

  final Random _random = Random();

  ChatThread? _thread;
  ChatThread? get thread => _thread;

  List<ChatMessage> get messages => _thread?.messages ?? const [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get isInitialLoad => _isLoading && _thread == null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _recorder;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Duration _recordingElapsed = Duration.zero;
  Duration get recordingElapsed => _recordingElapsed;

  /// `0:07` while recording.
  String get recordingLabel => VoiceNote.formatPosition(_recordingElapsed);

  final List<double> _recordingWaveform = [];

  /// The bars drawn in the composer as the patient speaks.
  List<double> get recordingWaveform => List.unmodifiable(_recordingWaveform);

  int _localSequence = 0;

  Future<void> open({
    required Doctor doctor,
    required ConsultationMode mode,
    String? anonymousDisplayName,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _thread = await _openChatThread(
        doctor: doctor,
        mode: mode,
        anonymousDisplayName: anonymousDisplayName,
      );
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendText(String body) async {
    final thread = _thread;
    final trimmed = body.trim();
    if (thread == null || trimmed.isEmpty) return;

    final pending = ChatMessage.text(
      id: _nextLocalId(),
      author: ChatAuthor.patient,
      sentAt: DateTime.now(),
      body: trimmed,
      status: ChatMessageStatus.sending,
    );

    _add(pending);

    await _settle(
      pending,
      () => _sendChatMessage.text(threadId: thread.id, body: trimmed),
    );
  }

  // --- Voice notes ---------------------------------------------------------

  /// Starts recording. The clip is only sent if [stopRecordingAndSend] is what
  /// ends it.
  ///
  /// TODO(chat): drive this from a real recorder. The elapsed time and the bars
  /// below stand in for its duration and amplitude callbacks; everything from
  /// [VoiceNote] onwards already matches what a recorder would hand over.
  void startRecording() {
    if (_isRecording || _thread == null) return;

    _isRecording = true;
    _recordingElapsed = Duration.zero;
    _recordingWaveform.clear();
    notifyListeners();

    _recorder = Timer.periodic(_recordingTick, (_) {
      _recordingElapsed += _recordingTick;
      _recordingWaveform.add(0.25 + _random.nextDouble() * 0.75);

      if (_recordingElapsed >= maxRecordingDuration) {
        stopRecordingAndSend();
        return;
      }

      notifyListeners();
    });
  }

  /// Throws the recording away.
  void cancelRecording() {
    if (!_isRecording) return;

    _stopRecorder();
    _recordingElapsed = Duration.zero;
    _recordingWaveform.clear();
    notifyListeners();
  }

  /// Ends the recording and sends it. A tap too short to be speech is
  /// discarded rather than posted as an empty bubble.
  Future<void> stopRecordingAndSend() async {
    final thread = _thread;
    if (!_isRecording || thread == null) return;

    final duration = _recordingElapsed;
    final waveform = List<double>.of(_recordingWaveform);

    _stopRecorder();
    _recordingElapsed = Duration.zero;
    _recordingWaveform.clear();

    if (duration < const Duration(seconds: 1)) {
      _errorMessage = tr('Hold the mic a little longer to record a note.');
      notifyListeners();
      return;
    }

    final note = VoiceNote(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      duration: duration,
      waveform: waveform,
    );

    final pending = ChatMessage.voice(
      id: _nextLocalId(),
      author: ChatAuthor.patient,
      sentAt: DateTime.now(),
      note: note,
      status: ChatMessageStatus.sending,
    );

    _add(pending);

    await _settle(
      pending,
      () => _sendChatMessage.voiceNote(threadId: thread.id, note: note),
    );
  }

  /// Clears a transient error once the screen has shown it.
  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  // --- Internals ----------------------------------------------------------

  /// Runs [send] and swaps the optimistic [pending] message for the stored one,
  /// or marks it failed.
  Future<void> _settle(
    ChatMessage pending,
    Future<ChatMessage> Function() send,
  ) async {
    try {
      _replace(pending.id, await send());
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      _replace(pending.id, pending.copyWith(status: ChatMessageStatus.failed));
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      _replace(pending.id, pending.copyWith(status: ChatMessageStatus.failed));
    }
  }

  void _add(ChatMessage message) {
    final thread = _thread;
    if (thread == null) return;

    _thread = thread.copyWith(messages: [...thread.messages, message]);
    notifyListeners();
  }

  void _replace(String id, ChatMessage message) {
    final thread = _thread;
    if (thread == null) return;

    _thread = thread.copyWith(
      messages: [
        for (final existing in thread.messages)
          if (existing.id == id) message else existing,
      ],
    );
    notifyListeners();
  }

  String _nextLocalId() => 'local-msg-${++_localSequence}';

  void _stopRecorder() {
    _isRecording = false;
    _recorder?.cancel();
    _recorder = null;
  }

  @override
  void dispose() {
    _stopRecorder();
    super.dispose();
  }
}
