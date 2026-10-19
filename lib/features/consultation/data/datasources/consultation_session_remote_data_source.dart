import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/consultation_mode.dart';
import '../../domain/entities/live_consultation.dart';

/// Brokers an instant consultation between a patient and a doctor.
///
/// Both sides of the call talk to this. The patient files a request and watches
/// it; the doctor watches for one arriving and answers it. Neither ever names a
/// channel — the API mints one per consultation and hands the same value to
/// both, which is what makes two simultaneous calls two separate rooms.
abstract interface class ConsultationSessionRemoteDataSource {
  // --- Patient --------------------------------------------------------------

  Future<LiveConsultation> requestInstant({
    required ConsultationMode mode,
    String? speciality,

    /// Binds the request to one doctor, when the patient picked a name off a
    /// listing. It rings them and nobody else, and times out rather than
    /// putting the patient through to somebody they did not choose.
    String? doctorId,
    bool isAnonymous = false,
    String? alias,

    /// What the patient wants to discuss, in their own words. Travels on the
    /// request rather than being typed once the call connects, because the
    /// doctor reads it while deciding whether to answer.
    String? concern,
  });

  /// Books a slot with a named doctor.
  ///
  /// Nothing is rung: the appointment is the agreement, and both diaries carry
  /// it until its time comes. Separate from [requestInstant] because a booking
  /// is meaningless without a doctor and a time, and an instant request has
  /// neither.
  Future<LiveConsultation> schedule({
    required String doctorId,
    required ConsultationMode mode,
    required DateTime scheduledAt,
    String? concern,
    bool isAnonymous = false,
    String? alias,
  });

  /// Polls one consultation until it connects or ends.
  ///
  /// Cancelling the subscription stops the polling but does **not** withdraw
  /// the request — [cancel] does that, and it is a decision the patient makes
  /// rather than something a disposed screen should do on their behalf.
  Stream<LiveConsultation> watch(String id);

  Future<LiveConsultation> cancel(String id);

  // --- Doctor ---------------------------------------------------------------

  /// Polls for a call ringing for the signed-in doctor. Emits null when there
  /// is nothing, so a screen can clear an incoming-call sheet as easily as it
  /// shows one.
  ///
  /// Doubles as the doctor's presence heartbeat: the API refreshes
  /// `lastSeenAt` on every one of these, which is what stops a doctor who
  /// force-quit from being rung forever.
  Stream<LiveConsultation?> watchIncoming();

  Future<LiveConsultation> accept(String id);

  Future<LiveConsultation> decline(String id);

  // --- Either side ----------------------------------------------------------

  /// Called as the call screen opens, by both parties. Idempotent.
  Future<LiveConsultation> join(String id);

  Future<LiveConsultation> end(String id);

  /// [rating] is the doctor and feeds their running average. [callQuality] is
  /// the connection and deliberately does not — a dropped call is not the
  /// doctor's fault, and charging them for it is how a star rating stops
  /// meaning anything.
  Future<void> rate(
    String id, {
    required int rating,
    String? feedback,
    int? callQuality,
    List<String> tags,
  });
}

/// Stands in when the app runs without a backend.
///
/// Nothing arrives and nothing can be answered, which is the honest behaviour
/// for a stub: an instant consultation is two real devices finding each other,
/// and there is no second device here to find. Kept so the widget tests and the
/// offline demo build have a registration to resolve rather than the screens
/// having to ask which backend they are on.
class FakeConsultationSessionRemoteDataSource
    implements ConsultationSessionRemoteDataSource {
  const FakeConsultationSessionRemoteDataSource();

  static const Failure _unavailable = Failure(
    'Consultations need a connection to the server.',
  );

  /// Never rings. Emits nothing at all rather than null, so a doctor's home
  /// screen shows no banner and no error either.
  @override
  Stream<LiveConsultation?> watchIncoming() => const Stream.empty();

  @override
  Stream<LiveConsultation> watch(String id) => const Stream.empty();

  @override
  Future<LiveConsultation> requestInstant({
    required ConsultationMode mode,
    String? speciality,
    String? doctorId,
    bool isAnonymous = false,
    String? alias,
    String? concern,
  }) async => throw _unavailable;

  @override
  Future<LiveConsultation> schedule({
    required String doctorId,
    required ConsultationMode mode,
    required DateTime scheduledAt,
    String? concern,
    bool isAnonymous = false,
    String? alias,
  }) async => throw _unavailable;

  @override
  Future<LiveConsultation> accept(String id) async => throw _unavailable;

  @override
  Future<LiveConsultation> decline(String id) async => throw _unavailable;

  @override
  Future<LiveConsultation> cancel(String id) async => throw _unavailable;

  @override
  Future<LiveConsultation> join(String id) async => throw _unavailable;

  @override
  Future<LiveConsultation> end(String id) async => throw _unavailable;

  @override
  Future<void> rate(
    String id, {
    required int rating,
    String? feedback,
    int? callQuality,
    List<String> tags = const [],
  }) async {
    throw _unavailable;
  }
}

/// What a patient is told when the booking route is not there.
///
/// Worded as a fact plus a way forward. Nothing they did was wrong, nothing was
/// charged — the slot is taken before the money by design — and an instant
/// consultation is a working alternative that reaches the same doctor.
const Failure _schedulingUnavailable = Failure(
  'Booking a slot is not available yet. '
  'You have not been charged — try an instant consultation instead.',
  code: 'scheduling_unavailable',
);

/// The consultation API.
///
/// | Method | Path                          |
/// | ------ | ----------------------------- |
/// | POST   | /consultations/instant        |
/// | POST   | /consultations/schedule       | a booking, with a named doctor
/// | GET    | /consultations/:id            | polled while waiting
/// | GET    | /consultations/incoming       | polled by the doctor
/// | POST   | /consultations/:id/accept     |
/// | POST   | /consultations/:id/decline    |
/// | POST   | /consultations/:id/cancel     |
/// | POST   | /consultations/:id/join       |
/// | POST   | /consultations/:id/end        |
/// | POST   | /consultations/:id/rate       |
class ApiConsultationSessionRemoteDataSource
    implements ConsultationSessionRemoteDataSource {
  const ApiConsultationSessionRemoteDataSource(this._client);

  final ApiClient _client;

  /// How often the patient's waiting screen re-checks. Short: the patient is
  /// staring at a spinner, and a doctor answering should feel immediate.
  static const Duration watchInterval = Duration(seconds: 2);

  /// How often a doctor's app checks for an incoming call. Longer than the
  /// patient's, because it runs whenever the doctor is online rather than only
  /// while a screen is open — and the ring lasts 30 seconds, so a few seconds
  /// of latency costs nothing.
  static const Duration incomingInterval = Duration(seconds: 3);

  @override
  Future<LiveConsultation> requestInstant({
    required ConsultationMode mode,
    String? speciality,
    String? doctorId,
    bool isAnonymous = false,
    String? alias,
    String? concern,
  }) async {
    final body = await _client.post(
      '/consultations/instant',
      body: {
        'mode': mode.name,
        'speciality': ?speciality,
        'doctorId': ?doctorId,
        if (isAnonymous) 'isAnonymous': true,
        if (isAnonymous && alias != null) 'alias': alias,
        if (concern != null && concern.trim().isNotEmpty)
          'concern': concern.trim(),
      },
    );

    return _required(body['consultation']);
  }

  @override
  Future<LiveConsultation> schedule({
    required String doctorId,
    required ConsultationMode mode,
    required DateTime scheduledAt,
    String? concern,
    bool isAnonymous = false,
    String? alias,
  }) async {
    final Map<String, Object?> body;
    try {
      body = await _client.post(
        '/consultations/schedule',
        body: {
          'doctorId': doctorId,
          'mode': mode.name,
          // UTC on the wire. The slot the patient tapped is a moment, and the
          // phone and the server are not guaranteed to agree on a timezone —
          // sending a local ISO string is how a 3 PM appointment arrives as
          // noon.
          'scheduledAt': scheduledAt.toUtc().toIso8601String(),
          if (concern != null && concern.trim().isNotEmpty)
            'concern': concern.trim(),
          if (isAnonymous) 'isAnonymous': true,
          if (isAnonymous && alias != null) 'alias': alias,
        },
      );
    } on Failure catch (failure) {
      // The route is not built yet, and the server says so by quoting it back:
      // "Cannot POST /consultations/schedule". That is a sentence for a
      // developer, not for a patient who has just picked a time — and the
      // patient cannot act on it at all, so it is replaced with what is
      // actually true and what they can do instead.
      if (failure.isNotFound) throw _schedulingUnavailable;
      rethrow;
    }

    return _required(body['consultation']);
  }

  @override
  Stream<LiveConsultation> watch(String id) {
    return _poll(
      every: watchInterval,
      read: () async {
        final body = await _client.get('/consultations/$id');
        return _required(body['consultation']);
      },
      // A consultation that connected or ended is not going to change again in
      // a way this stream's reader cares about.
      isFinal: (consultation) =>
          consultation.isConnectable || consultation.isOver,
    );
  }

  @override
  Stream<LiveConsultation?> watchIncoming() {
    return _poll<LiveConsultation?>(
      every: incomingInterval,
      read: () async {
        final body = await _client.get('/consultations/incoming');
        final consultation = body['consultation'];

        // Null is the ordinary answer, not an error: most polls find nothing.
        return consultation == null ? null : _required(consultation);
      },
      // Never done. A doctor's shift is a series of calls, so this runs until
      // the subscription is cancelled.
      isFinal: (_) => false,
    );
  }

  @override
  Future<LiveConsultation> cancel(String id) => _act(id, 'cancel');

  @override
  Future<LiveConsultation> accept(String id) => _act(id, 'accept');

  @override
  Future<LiveConsultation> decline(String id) => _act(id, 'decline');

  @override
  Future<LiveConsultation> join(String id) => _act(id, 'join');

  @override
  Future<LiveConsultation> end(String id) => _act(id, 'end');

  @override
  Future<void> rate(
    String id, {
    required int rating,
    String? feedback,
    int? callQuality,
    List<String> tags = const [],
  }) async {
    await _client.post(
      '/consultations/$id/rate',
      body: {
        'rating': rating,
        if (feedback != null && feedback.trim().isNotEmpty)
          'feedback': feedback.trim(),
        'callQuality': ?callQuality,
        if (tags.isNotEmpty) 'tags': tags,
      },
    );
  }

  Future<LiveConsultation> _act(String id, String action) async {
    final body = await _client.post('/consultations/$id/$action');
    return _required(body['consultation']);
  }

  /// Turns a periodic read into a stream.
  ///
  /// Driven by a timer rather than a loop of awaited delays, so cancelling the
  /// subscription really does stop the work — a polling loop that keeps running
  /// after its screen is gone is a battery drain nobody can see.
  ///
  /// An error is forwarded but does **not** close the stream: a single failed
  /// poll on a patchy connection should not end a call that is still being set
  /// up. The screen decides what a transient error is worth showing.
  static Stream<T> _poll<T>({
    required Duration every,
    required Future<T> Function() read,
    required bool Function(T) isFinal,
  }) {
    late final StreamController<T> controller;
    Timer? timer;
    var closed = false;
    var inFlight = false;

    Future<void> tick() async {
      // Skips rather than queues. On a slow connection a 2-second timer would
      // otherwise stack requests faster than they come back.
      if (inFlight || closed) return;
      inFlight = true;

      try {
        final value = await read();
        if (closed) return;

        controller.add(value);

        if (isFinal(value)) {
          timer?.cancel();
          await controller.close();
        }
      } catch (error) {
        if (!closed) controller.addError(error);
      } finally {
        inFlight = false;
      }
    }

    controller = StreamController<T>(
      onListen: () {
        tick();
        timer = Timer.periodic(every, (_) => tick());
      },
      onCancel: () {
        closed = true;
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  static LiveConsultation _required(Object? value) {
    final consultation = _consultationFrom(value);
    if (consultation == null) throw const Failure.unexpected();

    return consultation;
  }

  static LiveConsultation? _consultationFrom(Object? value) {
    if (value is! Map<String, Object?>) return null;

    final id = value['id'];
    final channelId = value['channelId'];
    final peerId = value['peerId'];

    // All three are what the call is made of. A response missing any of them is
    // not a consultation this app can act on, whatever else it contains.
    if (id is! String || channelId is! String || peerId is! String) return null;

    return LiveConsultation(
      id: id,
      status: LiveConsultationStatus.from(value['status'] as String?),
      mode: value['mode'] == 'audio'
          ? ConsultationMode.audio
          : ConsultationMode.video,
      channelId: channelId,
      peerId: peerId,
      isCaller: value['isCaller'] == true,
      patientName: value['patientName'] as String? ?? 'Patient',
      isAnonymous: value['isAnonymous'] == true,
      doctor: _doctorFrom(value['doctor']),
      fee: (value['fee'] as num?)?.toInt(),
      // Back to local time. It travels as UTC, and every screen that shows it —
      // the appointment card, the diary heading — is showing it to somebody
      // reading a clock on a wall.
      scheduledAt: DateTime.tryParse(
        value['scheduledAt'] as String? ?? '',
      )?.toLocal(),
      concern: _textOf(value['concern']),
    );
  }

  /// Null for a missing value and for a blank one alike: a concern that is an
  /// empty string is no concern, and a card drawn around nothing is worse than
  /// no card.
  static String? _textOf(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static Doctor? _doctorFrom(Object? value) {
    if (value is! Map<String, Object?>) return null;

    final id = value['id'];
    if (id is! String) return null;

    final video = (value['consultationFee'] as num?)?.toInt() ?? 0;
    final audio = (value['audioConsultationFee'] as num?)?.toInt();

    return Doctor(
      id: id,
      name: value['name'] as String? ?? 'Doctor',
      speciality: value['speciality'] as String? ?? 'General Physician',
      yearsOfExperience: (value['yearsOfExperience'] as num?)?.toInt() ?? 0,
      rating: (value['rating'] as num?)?.toDouble() ?? 0,
      consultationFee: video,
      audioConsultationFee: audio,
      isVerified: value['isVerified'] == true,
      isAvailableNow: value['isAvailableNow'] == true,
    );
  }
}
