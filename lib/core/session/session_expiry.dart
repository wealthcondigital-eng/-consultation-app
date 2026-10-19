import 'package:flutter/foundation.dart';

/// Announces that the server has rejected the stored session.
///
/// The app can hold a token that looks perfectly valid to it — unexpired,
/// well-formed, signed — for a user the server no longer has. Nothing local can
/// detect that: `AuthSession.restore` only reads the clock, and the account is
/// gone on the other side of the network. The first *request* is what finds
/// out, and until this existed nothing carried that discovery back up, so a
/// launch whose every lookup was refused still routed into the app — a doctor
/// onto the certificate upload form, a patient onto a dashboard where nothing
/// loaded, neither with a way back to the role choice.
///
/// `ApiClient` raises this on any 401 and the app listens once, above the
/// navigator. One listener rather than a check in every data source: a screen
/// that forgot to handle it was a screen that stranded the user, and there is
/// no reasonable behaviour for a single caller to pick anyway — the answer is
/// always the same, and it is a whole-app one.
class SessionExpiry extends ChangeNotifier {
  bool _isExpired = false;
  bool _isClaimed = false;

  /// True from the first rejected request until a new session begins.
  bool get isExpired => _isExpired;

  /// Called by `ApiClient` when the server answers 401.
  ///
  /// Repeated calls are deliberately silent, and stay silent until [reset] —
  /// which is to say until somebody actually signs in again. A launch fires
  /// several requests at once — the admin check, the doctor application, the
  /// patient profile — and all of them fail together, which would otherwise be
  /// three sign-outs and three snackbars for one dead session.
  ///
  /// Staying latched is what stops the app eating itself. Reacting to an expiry
  /// means signing out, and signing out is itself an API call that carries the
  /// same refused token, so it comes back 401 too. While [claim] cleared this
  /// flag, that second 401 re-armed the listener, which signed out again, which
  /// was refused again — an unbounded loop that pushed a fresh landing screen
  /// on every pass and ended in a crash. One dead session is one expiry, no
  /// matter how many requests discover it or what the recovery itself has to
  /// send.
  void expire() {
    if (_isExpired) return;
    _isExpired = true;
    _isClaimed = false;
    notifyListeners();
  }

  /// Takes responsibility for *telling the user*, and returns true only to
  /// whoever gets there first.
  ///
  /// Two places can react to the same 401 and their order is not fixed. During
  /// a launch the app-wide listener sees it while the splash is still awaiting
  /// its lookups, so the listener claims it and the splash — which arrives a
  /// moment later with a `sessionExpired` destination — finds it already taken
  /// and stays quiet rather than repeating the message. Whichever loses the
  /// race still routes to the landing screen; only the telling is claimed.
  ///
  /// Claiming no longer clears [isExpired]: who says it and whether it happened
  /// are different questions, and answering both with one flag is what made the
  /// loop above possible.
  bool claim() {
    if (!_isExpired || _isClaimed) return false;
    _isClaimed = true;
    return true;
  }

  /// Forgets the expiry, because a new session has begun.
  ///
  /// Called from `AuthSession.begin`. Without it the latch above would be
  /// permanent: the next genuine expiry, hours later on a session that was
  /// signed in again since, would find the flag already set and tell nobody.
  void reset() {
    _isExpired = false;
    _isClaimed = false;
  }
}
