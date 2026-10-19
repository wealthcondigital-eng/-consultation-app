/// How the patient pays.
enum PaymentMethod {
  upi('UPI (GPay, PhonePe, Paytm)'),
  card('Credit or Debit Card'),
  netBanking('Net Banking');

  const PaymentMethod(this.label);

  final String label;

  /// Only UPI collects extra detail inline before the payment can start.
  bool get needsUpiId => this == PaymentMethod.upi;
}

/// UPI apps offered as a shortcut instead of typing an ID.
enum UpiApp {
  googlePay('Google Pay'),
  phonePe('PhonePe'),
  paytm('Paytm');

  const UpiApp(this.label);

  final String label;
}
