import '../../../../core/network/api_client.dart';

/// What the peer has posted that this device has not seen.
class SignalInbox {
  const SignalInbox({
    this.descriptionType,
    this.sdp,
    this.candidates = const [],
    this.nextCandidate = 0,
    this.consultationStatus,
    this.durationSeconds = 0,
    this.isConnectedOnServer = false,
  });

  /// `offer` or `answer`, or null when the peer has not posted one yet.
  final String? descriptionType;

  /// The peer's session description, passed through as WebRTC gave it.
  final Map<String, dynamic>? sdp;

  /// ICE candidates after the cursor sent with the request.
  final List<Map<String, dynamic>> candidates;

  /// Cursor for the next poll. Candidates arrive incrementally rather than
  /// being re-sent in full every second for the length of the call.
  final int nextCandidate;

  /// The consultation's status, carried on the same response.
  ///
  /// This is how a hang-up reaches the other phone. A peer connection notices a
  /// clean close, but not a phone that lost signal or was killed — so the
  /// record is the authority on whether the call is still on, and it costs no
  /// extra request to ask.
  final String? consultationStatus;

  /// How long the call has run, per the **server's** clock, so both phones show
  /// the same number.
  final int durationSeconds;

  /// True once the server has recorded the call as connected — from then on
  /// [durationSeconds] counts from the connection, not from when the call
  /// screen opened, and is safe to show.
  final bool isConnectedOnServer;

  bool get isOver =>
      consultationStatus == 'completed' ||
      consultationStatus == 'cancelled' ||
      consultationStatus == 'expired';
}

/// WebRTC signalling, scoped to one consultation.
///
/// Replaces the unauthenticated `/call/*` routes on the Express service. Two
/// things change, and both were bugs:
///
///  * **Nobody says who they are.** The party is read from the bearer token
///    server-side. The app used to send a `sender` string; both sides sent the
///    doctor's id, so each discarded the other's offer as its own echo.
///  * **Only the two people in the consultation can reach the channel.** The
///    old routes took a channel name and no token, so anyone who learned one
///    could join a medical call.
class CallSignallingClient {
  const CallSignallingClient(this._client);

  final ApiClient _client;

  /// STUN and TURN, from the server.
  ///
  /// Fetched rather than hard-coded because a TURN credential compiled into an
  /// APK is a public credential, and because **STUN alone does not connect two
  /// phones on mobile data** — carrier-grade NAT means neither side can be
  /// reached directly and the media has to be relayed. The server decides what
  /// relay to use and mints a short-lived credential for it.
  Future<List<Map<String, dynamic>>> iceServers() async {
    final body = await _client.get('/consultations/ice-servers');
    final servers = body['iceServers'];

    if (servers is! List) return const [];

    return [
      for (final server in servers.whereType<Map<String, Object?>>())
        {
          'urls': server['urls'],
          if (server['username'] != null) 'username': server['username'],
          if (server['credential'] != null) 'credential': server['credential'],
        },
    ];
  }

  Future<void> sendOffer(String consultationId, Map<String, dynamic> sdp) =>
      _post(consultationId, {'kind': 'offer', 'type': 'offer', 'sdp': sdp});

  Future<void> sendAnswer(String consultationId, Map<String, dynamic> sdp) =>
      _post(consultationId, {'kind': 'answer', 'type': 'answer', 'sdp': sdp});

  Future<void> sendCandidate(
    String consultationId,
    Map<String, dynamic> candidate,
  ) => _post(consultationId, {'kind': 'candidate', 'candidate': candidate});

  Future<SignalInbox> poll(String consultationId, {int after = 0}) async {
    final body = await _client.get(
      '/consultations/$consultationId/signal?after=$after',
    );

    final signal = body['signal'];
    final consultation = body['consultation'];

    if (signal is! Map<String, Object?>) return const SignalInbox();

    final description = signal['description'];

    return SignalInbox(
      descriptionType: description is Map<String, Object?>
          ? description['type'] as String?
          : null,
      sdp: description is Map<String, Object?>
          ? (description['sdp'] as Map?)?.cast<String, dynamic>()
          : null,
      candidates: [
        for (final candidate in (signal['candidates'] as List? ?? const []))
          if (candidate is Map) candidate.cast<String, dynamic>(),
      ],
      nextCandidate: (signal['nextCandidate'] as num?)?.toInt() ?? after,
      consultationStatus: consultation is Map<String, Object?>
          ? consultation['status'] as String?
          : null,
      durationSeconds: consultation is Map<String, Object?>
          ? (consultation['durationSeconds'] as num?)?.toInt() ?? 0
          : 0,
      isConnectedOnServer:
          consultation is Map<String, Object?> &&
          consultation['connectedAt'] != null,
    );
  }

  /// Tells the server the call has connected, which starts its clock — see
  /// `ConsultationsService.markConnected`. Idempotent server-side.
  Future<void> markConnected(String consultationId) async {
    await _client.post('/consultations/$consultationId/connected');
  }

  Future<void> _post(String consultationId, Map<String, Object?> body) async {
    await _client.post('/consultations/$consultationId/signal', body: body);
  }
}
