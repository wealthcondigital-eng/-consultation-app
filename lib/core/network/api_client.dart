import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../config/app_config.dart';
import 'connectivity_monitor.dart';
import '../error/failure.dart';
import '../logging/auth_logger.dart';
import '../session/auth_session.dart';
import '../session/session_expiry.dart';

/// Thin JSON client for the consultation API in `server/`.
///
/// Two jobs beyond `http`: it attaches the bearer token from [AuthSession], and
/// it turns every failure — transport, HTTP status, or a malformed body — into
/// a [Failure] whose message is already fit to show the user. Nothing above
/// this class handles a `SocketException` or reads a status code.
class ApiClient {
  ApiClient(
    this._session,
    this._expiry,
    this._connectivity, {
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final AuthSession _session;

  /// Told about every request that reached the server and every one that could
  /// not. Ordinary screen traffic is what detects a dropped connection, so the
  /// app does not need a poller running in the background to notice.
  final ConnectivityMonitor _connectivity;

  /// Raised on, not read: a 401 is the only way the app finds out that the
  /// account behind a locally-valid token is gone.
  final SessionExpiry _expiry;
  final http.Client _http;

  /// Long enough for a cold serverless start, short enough that the spinner
  /// does not outlast the user's patience.
  static const Duration timeout = Duration(seconds: 20);

  /// [signalsExpiry] is false for a *probe* — a call whose failure the caller
  /// has already decided to tolerate, and which therefore must not be able to
  /// end the session as a side effect.
  ///
  /// An admin check answered with a 401 is the case this exists for. Whether
  /// the route refuses a non-admin with a 401 or a 403 is the server's business
  /// and not something the app should be signed out over — and nothing is lost
  /// by staying quiet, because a session that really is dead fails the very
  /// next lookup too, where the answer is read rather than shrugged off.
  Future<Map<String, Object?>> get(String path, {bool signalsExpiry = true}) =>
      _send(
        'GET $path',
        () => _http.get(_uri(path), headers: _headers()),
        signalsExpiry: signalsExpiry,
      );

  Future<Map<String, Object?>> post(
    String path, {
    Map<String, Object?> body = const {},
  }) => _send(
    'POST $path',
    () => _http.post(_uri(path), headers: _headers(), body: jsonEncode(body)),
  );

  /// Partial update. Used where the app edits some fields of a record and must
  /// not send the ones it does not own — a patient's verified phone number, for
  /// instance, which is the session's to set and not the form's.
  Future<Map<String, Object?>> patch(
    String path, {
    Map<String, Object?> body = const {},
  }) => _send(
    'PATCH $path',
    () => _http.patch(_uri(path), headers: _headers(), body: jsonEncode(body)),
  );

  /// Full replacement. Used where the screen owns the whole record and a merge
  /// would be wrong — an availability schedule, where a window the doctor
  /// removed has to actually disappear.
  Future<Map<String, Object?>> put(
    String path, {
    Map<String, Object?> body = const {},
  }) => _send(
    'PUT $path',
    () => _http.put(_uri(path), headers: _headers(), body: jsonEncode(body)),
  );

  Future<Map<String, Object?>> delete(String path) => _send(
    'DELETE $path',
    () => _http.delete(_uri(path), headers: _headers()),
  );

  /// Uploads one file as `multipart/form-data`, under the field name [field].
  ///
  /// Separate from [post] because the body is not JSON and the content type has
  /// to be the boundary-carrying one `MultipartRequest` generates — setting
  /// `application/json` here would make the server reject the parse.
  ///
  /// [contentType] is the type of the *part*, not of the request, and it is
  /// worth passing every time. `MultipartFile.fromPath` does not sniff the
  /// file: with nothing given it labels the part `application/octet-stream`,
  /// which is what the API sees, checks against its allowlist, and refuses —
  /// and it is also what the review console would later have to render from.
  Future<Map<String, Object?>> uploadFile(
    String path, {
    required String field,
    required String filePath,
    String? contentType,
    Map<String, String> fields = const {},
  }) {
    return _send('UPLOAD $path', () async {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(_headers(json: false))
        ..fields.addAll(fields)
        ..files.add(
          await http.MultipartFile.fromPath(
            field,
            filePath,
            contentType: contentType == null
                ? null
                : MediaType.parse(contentType),
          ),
        );

      // `send` answers a streamed response; the callers below all read a small
      // JSON body, so it is collected here rather than exposed as a stream.
      return http.Response.fromStream(await request.send());
    });
  }

  /// Fetches a file the API guards behind the bearer token.
  ///
  /// Separate from [get] because the answer is not JSON and must not be parsed
  /// as any — a certificate is a PDF or a scan, and the only reason it comes
  /// through the app at all rather than a link is that a URL anyone could open
  /// either expires and breaks or does not expire and leaks identity
  /// paperwork.
  ///
  /// Does **not** go through [_send], which reads a body as text. The bytes are
  /// taken as bytes, and the same failures are translated the same way.
  Future<DownloadedFile> download(String path) async {
    final http.Response response;

    try {
      response = await _http
          .get(_uri(path), headers: _headers(json: false))
          .timeout(timeout);
      _connectivity.reportReachable();
    } on TimeoutException {
      _connectivity.reportUnreachable();
      throw Failure(
        'Could not reach the server at ${AppConfig.apiBaseUrl}. '
        'Check that it is running and try again.',
      );
    } on SocketException {
      _connectivity.reportUnreachable();
      throw const Failure.network();
    } on http.ClientException {
      _connectivity.reportUnreachable();
      throw const Failure.network();
    }

    if (response.statusCode == 401) {
      throw _rejectSession(null);
    }

    if (response.statusCode == 404) {
      throw const Failure('That file is no longer on file.');
    }

    if (response.statusCode >= 400) {
      throw const Failure.unexpected();
    }

    return DownloadedFile(
      bytes: response.bodyBytes,
      // The server's own answer, not a guess from the file name: what the app
      // has to decide from this is whether to render it as an image or as a
      // PDF, and a certificate saved as `scan` with no extension is common.
      mimeType:
          response.headers['content-type']?.split(';').first.trim() ??
          'application/octet-stream',
    );
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  /// [json] is false for a multipart upload, where the content type has to be
  /// the boundary-carrying one the request builds for itself.
  Map<String, String> _headers({bool json = true}) {
    final token = _session.token;
    return {
      if (json) 'content-type': 'application/json',
      'accept': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };
  }

  /// [label] is the method and path, carried in only so a refused request can
  /// name itself in the log. Diagnosing "it sends me back to the start" means
  /// knowing *which* call was refused, and the failure the caller sees has been
  /// turned into user-facing copy by then — by design, and useless here.
  Future<Map<String, Object?>> _send(
    String label,
    Future<http.Response> Function() request, {
    bool signalsExpiry = true,
  }) async {
    final http.Response response;

    try {
      response = await request().timeout(timeout);
      // Whatever it answered, something answered.
      _connectivity.reportReachable();
    } on TimeoutException {
      _connectivity.reportUnreachable();
      // Names the address on purpose. The usual cause is not a slow server but
      // an unreachable one — the API not running, or `API_BASE_URL` still
      // pointing at the emulator's 10.0.2.2 while the build is on a real
      // device, where nothing answers and the connection hangs rather than
      // being refused.
      throw Failure(
        'Could not reach the server at ${AppConfig.apiBaseUrl}. '
        'Check that it is running and try again.',
      );
    } on SocketException {
      _connectivity.reportUnreachable();
      throw const Failure.network();
    } on http.ClientException {
      _connectivity.reportUnreachable();
      throw const Failure.network();
    }

    // 204 from sign-out, and anything else that answers with no body.
    if (response.body.isEmpty) {
      if (response.statusCode == 401) {
        throw _rejectSession(null, signalsExpiry: signalsExpiry);
      }
      if (response.statusCode >= 400) throw const Failure.unexpected();
      return const {};
    }

    final Map<String, Object?> json;
    try {
      json = jsonDecode(response.body) as Map<String, Object?>;
    } catch (_) {
      // An HTML error page from a proxy in front of the API is the usual
      // cause, and it is worth distinguishing from the API saying no.
      throw const Failure('The server sent a response the app could not read.');
    }

    if (response.statusCode >= 400) {
      final error = json['error'];
      final body = error is Map ? error : json;

      AuthLogger.event('API · refused', {
        'request': label,
        'status': response.statusCode,
        'code': body['code'] ?? '(none)',
        'message': body['message'] ?? '(none)',
        'sent a token': _session.token != null,
      });
    }

    if (response.statusCode == 401) {
      throw _rejectSession(json, signalsExpiry: signalsExpiry);
    }
    if (response.statusCode >= 400) throw _toFailure(json, response);

    return json;
  }

  /// Ends the session on a 401, and returns the [Failure] to throw.
  ///
  /// Handled here rather than per call site because every caller's answer is
  /// the same and the cost of one forgetting was the user being stranded: the
  /// old code let a 401 fall through as an ordinary error, so a launch whose
  /// lookups were all refused still routed into the app — onto a doctor
  /// registration form, or a patient dashboard that could load nothing.
  ///
  /// The code is normalised so callers test one constant rather than knowing
  /// that `/auth/*` says `session_missing` and the NestJS side `session_invalid`.
  /// The server's own message is kept where it sent one: it already reads
  /// "Please sign in again to continue."
  Failure _rejectSession(
    Map<String, Object?>? json, {
    bool signalsExpiry = true,
  }) {
    // A 401 on a request that carried no token says nothing new: it means the
    // user is signed out, which is already true. Raising an expiry for it would
    // announce the end of a session that has already ended — and every call the
    // sign-out path itself makes is exactly that kind of request.
    if (signalsExpiry && _session.token != null) _expiry.expire();

    final error = json?['error'];
    final body = error is Map ? error : json;
    final message = body?['message'];

    return Failure(
      message is String && message.isNotEmpty
          ? message
          : 'Your session has ended. Please sign in again.',
      code: Failure.sessionExpired,
    );
  }

  /// The server's `{ error: { code, message } }` becomes a [Failure].
  ///
  /// The message is used as sent: the API writes user-facing copy on purpose,
  /// so error wording lives in one place rather than being duplicated per
  /// client. `code` is carried through rather than dropped, because a few
  /// screens have to *act* on it — see [Failure.isRateLimited].
  Failure _toFailure(Map<String, Object?> json, http.Response response) {
    final error = json['error'];
    final body = error is Map ? error : json;

    final message = body['message'];
    final retryAfter = _retryAfter(body, response);

    // 429 is the status every gateway agrees on, so it is trusted over a
    // missing code. Without this the OTP screen could not tell "wrong code"
    // from "stop asking", and kept asking — which on most SMS gateways extends
    // the very window it was waiting out.
    final code = switch (body['code']) {
      final String code when code.isNotEmpty => code,
      _ when response.statusCode == 429 => Failure.rateLimited,
      _ => null,
    };

    if (message is String && message.isNotEmpty) {
      return Failure(message, code: code, retryAfter: retryAfter);
    }

    if (code == Failure.rateLimited) {
      return Failure(
        'Too many attempts. Please wait a moment and try again.',
        code: code,
        retryAfter: retryAfter,
      );
    }

    return const Failure.unexpected();
  }

  /// How long the server wants to be left alone, from whichever of the three
  /// places it said so: the standard header, or either of the two field names
  /// the two API processes use.
  static Duration? _retryAfter(
    Map<Object?, Object?> body,
    http.Response response,
  ) {
    final seconds = switch (body['retryAfterSeconds'] ??
        body['resendAfterSeconds']) {
      final num value => value.toInt(),
      final String value => int.tryParse(value),
      _ => int.tryParse(response.headers['retry-after'] ?? ''),
    };

    if (seconds == null || seconds <= 0) return null;

    return Duration(seconds: seconds);
  }

  void close() => _http.close();
}

/// A file fetched from the API, and what it is.
class DownloadedFile {
  const DownloadedFile({required this.bytes, required this.mimeType});

  final Uint8List bytes;

  /// `application/pdf`, `image/jpeg`. What decides how it is shown.
  final String mimeType;

  bool get isPdf => mimeType == 'application/pdf';

  bool get isImage => mimeType.startsWith('image/');
}
