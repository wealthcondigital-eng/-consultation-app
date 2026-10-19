/// A failure the UI can show to the user.
///
/// Data sources throw these instead of leaking transport-level exceptions, so
/// the presentation layer never has to know what went wrong underneath.
class Failure implements Exception {
  const Failure(this.message, {this.code, this.retryAfter});

  /// Already user-facing — safe to put straight into a snackbar.
  final String message;

  /// The API's machine-readable `error.code`, where it sent one.
  ///
  /// Only consulted where the app has to **act** differently rather than say
  /// something different — the OTP screen holds its Resend button shut on
  /// [rateLimited], because a request the server is going to refuse is worse
  /// than no request: on most gateways a refused send still counts against the
  /// window, so retrying is what keeps the lockout alive.
  final String? code;

  /// How long until the same call is worth making again, when the server said.
  ///
  /// Carried out of the data layer rather than parsed from the message,
  /// because a countdown built by scraping English out of a sentence breaks the
  /// first time that sentence is reworded.
  final Duration? retryAfter;

  const Failure.network()
    : message = 'No connection. Check your network and try again.',
      code = 'network',
      retryAfter = null;

  const Failure.unexpected()
    : message = 'Something went wrong. Please try again.',
      code = null,
      retryAfter = null;

  /// The code the API uses for "too many requests", and what [isRateLimited]
  /// tests against. Named here so the two ends of the check cannot drift.
  static const String rateLimited = 'rate_limited';

  /// True when the server refused because it is being asked too often.
  ///
  /// Matches the code where one was sent, and falls back to the message for
  /// the gateways that answer 429 with prose and no code — which is exactly the
  /// case that left the OTP screen retrying into a lockout it could not see.
  bool get isRateLimited {
    if (code == rateLimited) return true;

    final text = message.toLowerCase();
    return text.contains('too many') || text.contains('rate limit');
  }

  /// True when the number is already registered under the other role. The
  /// landing flow turns this into an explanation naming the right way in,
  /// rather than a generic refusal.
  bool get isRoleConflict => code == 'role_conflict';

  /// The code this app normalises every 401 to, whichever wording the two API
  /// processes used — `session_missing` when no header was sent,
  /// `session_invalid` when the token named a user the server cannot find.
  ///
  /// Both mean the same thing to the app: the stored session is no longer worth
  /// anything and only signing in again will fix it.
  static const String sessionExpired = 'session_expired';

  /// True when the server refused the session itself, rather than the request.
  ///
  /// Distinct from [Failure.network] on purpose, and the distinction decides
  /// where a launch lands: a lookup that failed because the network is down
  /// says nothing about who the user is and must not sign anyone out, while one
  /// refused with a 401 means the account behind the token is gone.
  bool get isSessionExpired => code == sessionExpired;

  /// True when a resource (e.g. doctor application or patient profile) was not found (HTTP 404).
  bool get isNotFound {
    if (code == '404' || code == 'not_found') return true;
    final text = message.toLowerCase();
    return text.contains('not found') ||
        text.contains('no application') ||
        text.contains('profile is not set up');
  }

  @override
  String toString() => 'Failure($message)';
}
