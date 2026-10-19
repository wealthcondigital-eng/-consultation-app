/// What the patient is charged, itemised.
class FeeBreakdown {
  const FeeBreakdown({
    required this.consultationFee,
    required this.platformFee,
    this.currencySymbol = '₹',
  });

  /// Whole currency units — rupees, not paise.
  final int consultationFee;
  final int platformFee;
  final String currencySymbol;

  int get total => consultationFee + platformFee;

  String format(int amount) => '$currencySymbol$amount';

  String get formattedConsultationFee => format(consultationFee);
  String get formattedPlatformFee => format(platformFee);
  String get formattedTotal => format(total);
}
