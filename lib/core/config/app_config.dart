import 'package:flutter/foundation.dart';

/// Backend endpoints.
///
/// Nothing secret belongs here. The SMS India Hub API key in particular lives
/// in `server/.env` and never in the app: anything compiled into the binary can
/// be read out of the APK, and that key can send messages on your account. The
/// same goes for any database credential — the app reaches MongoDB only through
/// the API, never directly.
///
/// Every value stays overridable, so pointing a build at a laptop or a staging
/// host needs no edit to this file:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
/// ```
class AppConfig {
  const AppConfig._();

  /// The consultation API — nginx on the production subdomain, which fronts
  /// both Node services and hides the split: `/auth/*` and `/call/*` reach the
  /// Express service on :4000, everything else the NestJS service on :4100.
  /// One base URL, no port, and the app never learns there are two processes.
  ///
  /// Defaults to the production subdomain, so a release build reaches the
  /// backend with no `--dart-define` at all. `hasApi` still guards the case of
  /// a build that deliberately blanks it out.
  ///
  /// HTTPS is not optional here. `network_security_config.xml` forbids
  /// cleartext to every host but the loopback aliases, so an `http://` value
  /// for a real domain is refused by Android before the request is sent.
  ///
  /// Overriding for local work: `http://10.0.2.2:4000` from the Android
  /// emulator, `http://localhost:4000` from the iOS simulator. A LAN address
  /// needs a matching entry in `network_security_config.xml` — the cleartext
  /// exception list covers only `10.0.2.2`, `localhost` and `127.0.0.1`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.nesliferesearch.com',
  );

  static bool get hasApi => apiBaseUrl.isNotEmpty;

  // --- Payments -------------------------------------------------------------

  /// The Razorpay **key id**, e.g. `rzp_test_xxxxxxxx`.
  ///
  /// The key id is public by design — it identifies the account to Razorpay's
  /// checkout and is meant to ship in the client. The key **secret** is not,
  /// and is not here: it signs orders and verifies payments, and anything
  /// holding it can charge on your account. It belongs in `server/.env`.
  ///
  /// Defaults to the test key, for the same reason [apiBaseUrl] defaults to the
  /// production subdomain: a build that needs a `--dart-define` to reach a
  /// working state is a build that is broken by default, and this one was —
  /// with no key the payment screen fell through to its own form and Razorpay
  /// never opened at all, which is exactly what it looked like from the outside.
  ///
  /// This is only the fallback. The key that actually opens checkout comes back
  /// on the order from `POST /payments/order`, so rotating one or switching the
  /// platform to live is a server change rather than a release. Override it for
  /// a build that should not reach the test account at all:
  ///
  /// ```
  /// flutter build apk --dart-define=RAZORPAY_KEY_ID=rzp_live_xxxxxxxx
  /// ```
  ///
  /// **Development and production use different keys.** A debug or profile
  /// build — `flutter run` — falls back to the **test** key, so a developer's
  /// phone can never move real money. A release build — the AAB on Play —
  /// falls back to the **live** key. `RAZORPAY_KEY_ID`, when given, overrides
  /// both. Key IDs are public by design; the secrets live only on the server.
  static String get razorpayKeyId {
    if (_razorpayKeyOverride.isNotEmpty) return _razorpayKeyOverride;
    return kReleaseMode ? razorpayLiveKeyId : razorpayTestKeyId;
  }

  static const String _razorpayKeyOverride = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
  );

  /// The Razorpay **test** key ID — development builds.
  static const String razorpayTestKeyId = String.fromEnvironment(
    'RAZORPAY_TEST_KEY_ID',
    defaultValue: 'rzp_test_Tf8knyMTGy8AhE',
  );

  /// The Razorpay **live** key ID — release builds. Set it here (or pass
  /// `--dart-define=RAZORPAY_LIVE_KEY_ID=rzp_live_…`). Empty is safe: the
  /// server names the key on every order, and that is the one checkout uses.
  static const String razorpayLiveKeyId = String.fromEnvironment(
    'RAZORPAY_LIVE_KEY_ID',
    defaultValue: 'rzp_live_TnJwnS5iEdyISH',
  );

  /// A Razorpay **payment link**, e.g. `https://rzp.io/rzp/xxxxxxx`.
  ///
  /// Only used when no [razorpayKeyId] is set. It is the weaker of the two
  /// paths — a link carries its own fixed amount, so it bills what it was
  /// created for rather than what the consultation costs, and nothing comes
  /// back to the app to say it was paid. Useful for trying the Razorpay page
  /// end to end on a device; not a billing mechanism.
  ///
  /// ```
  /// flutter build apk --dart-define=RAZORPAY_PAYMENT_LINK=https://rzp.io/rzp/PaolPZq
  /// ```
  static const String razorpayPaymentLink = String.fromEnvironment(
    'RAZORPAY_PAYMENT_LINK',
  );

  /// True when a real checkout can be opened.
  static bool get hasPaymentGateway => razorpayKeyId.isNotEmpty;

  /// True when there is a link to fall back to.
  static bool get hasPaymentLink => razorpayPaymentLink.isNotEmpty;

  // Whether the gateway collects the payment method itself is deliberately
  // **not** here any more. It is `PaymentGateway.collectsMethodItself`, asked of
  // the gateway that will actually run, because the two answers differ exactly
  // where it matters: a build with a key configured still runs the simulated
  // gateway under test and on the fake backend. A screen that hid its picker on
  // the strength of a compile-time constant hid it there too, leaving no
  // picker, no sheet and nothing to tap.

  /// Whether the configured key is a test one. Test keys cannot move money, so
  /// the payment screen says so rather than letting anybody believe otherwise.
  static bool get isTestGateway => razorpayKeyId.startsWith('rzp_test');
}
