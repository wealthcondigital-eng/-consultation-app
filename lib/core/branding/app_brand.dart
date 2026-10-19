/// What the app is called, in one place.
///
/// The name was written out by hand in five: the splash wordmark, the landing
/// header, the window title, the Razorpay checkout sheet and the Android
/// label — and three of them still said `MediCare` long after the product was
/// not called that. A name that lives in five files is a name that gets renamed
/// in four.
///
/// The Android label and the iOS bundle name cannot read Dart, so those two
/// stay in `AndroidManifest.xml` and `Info.plist`. They are the only copies.
abstract final class AppBrand {
  /// The product, as a person says it.
  static const String name = 'Teleconsult';

  /// Under the wordmark on the splash and the landing screen.
  static const String tagline = 'Care. Anytime. Anywhere.';

  /// The company behind it, as it appears on a contract or a payment.
  ///
  /// Not the same string as [name] and deliberately so: a patient consults
  /// Teleconsult, and the entity that owes them a refund is Neslife Research
  /// Private Limited. Anywhere the second is the honest answer — the payment
  /// sheet, the policies — it is this one that is used.
  static const String legalEntity = 'Neslife Research Private Limited';

  /// Where the service lives. Shown on the policies, and the address a patient
  /// checks the app against.
  static const String domain = 'consult.nesliferesearch.com';
}
