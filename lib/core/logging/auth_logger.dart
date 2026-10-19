import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Traces the authentication and session lifecycle to the run console.
///
/// Every method is a no-op outside debug builds. That is deliberate rather
/// than tidiness: these lines carry a phone number, a user id and a live
/// bearer token, and anything holding that token can act as the patient until
/// it expires. It must never reach a release build, and these logs should not
/// be pasted anywhere public.
class AuthLogger {
  const AuthLogger._();

  /// Prints a titled block of aligned key/value pairs.
  ///
  /// Null values are kept rather than dropped — "the email is null" is usually
  /// the thing being diagnosed.
  static void event(String title, [Map<String, Object?> fields = const {}]) {
    if (!kDebugMode) return;

    debugPrint('┌─ $title');
    if (fields.isNotEmpty) {
      final width = fields.keys
          .map((key) => key.length)
          .reduce((a, b) => a > b ? a : b);

      fields.forEach((key, value) {
        debugPrint('│  ${key.padRight(width)}   ${value ?? '(null)'}');
      });
    }
    debugPrint('└─');
  }

  /// Prints the API's session token: the claims that decide access, then the
  /// raw JWT wrapped so it stays readable.
  static void token(String label, String? jwt) {
    if (!kDebugMode) return;

    if (jwt == null) {
      event('TOKEN · $label', {'token': '(none — signed out)'});
      return;
    }

    final claims = _claims(jwt);
    final expiry = claims['exp'];

    event('TOKEN · $label', {
      'user id (sub)': claims['sub'],
      'phone': claims['phone'],
      'role': claims['role'] ?? '(none recorded yet)',
      'issuer': claims['iss'],
      'expires in': expiry is int ? _remaining(expiry) : '(unknown)',
    });

    _wrapped(jwt).forEach(debugPrint);
    debugPrint('└─');
  }

  /// The payload segment, base64url-decoded. Signature is not verified — this
  /// is for reading claims locally, never for trusting them.
  static Map<String, dynamic> _claims(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return const {};

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  static String _remaining(int expiresAtSeconds) {
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAtSeconds * 1000);
    final left = expiry.difference(DateTime.now());

    if (left.isNegative) return 'expired (sign in again)';
    // Sessions last weeks, so minutes alone would print a five-digit number.
    if (left.inDays > 0) return '${left.inDays}d ${left.inHours % 24}h';
    return '${left.inMinutes}m ${left.inSeconds % 60}s';
  }

  /// `debugPrint` throttles long lines, so the JWT is chunked by hand.
  static List<String> _wrapped(String jwt) {
    const width = 64;
    final lines = <String>['┌─ TOKEN · raw JWT'];

    for (var i = 0; i < jwt.length; i += width) {
      final end = i + width < jwt.length ? i + width : jwt.length;
      lines.add('│  ${jwt.substring(i, end)}');
    }
    return lines;
  }
}
