/// A dialling country for the phone-number field.
///
/// The app serves India, and [india] is the only country it offers: the field
/// shows `+91` as a fixed prefix rather than a picker. The type stays because
/// it is what the formatter and the validator read — [digitGroups] drives both
/// the display format and the expected length — so opening a second market
/// means adding a constant here and putting the picker back, not reworking
/// either of them.
class Country {
  const Country({
    required this.isoCode,
    required this.name,
    required this.dialCode,
    required this.flag,
    required this.digitGroups,
  });

  final String isoCode;
  final String name;

  /// Including the leading '+'.
  final String dialCode;

  final String flag;

  /// How the national number is chunked when displayed — [5, 5] renders
  /// `98765 43210`.
  final List<int> digitGroups;

  /// Total national-number length.
  int get digitCount => digitGroups.fold(0, (sum, group) => sum + group);

  /// A placeholder in this country's own format, e.g. `98765 43210`.
  String get sampleNumber {
    const pool = '9876543210';
    var index = 0;
    return digitGroups
        .map(
          (group) =>
              List.generate(group, (_) => pool[index++ % pool.length]).join(),
        )
        .join(' ');
  }

  static const india = Country(
    isoCode: 'IN',
    name: 'India',
    dialCode: '+91',
    flag: '🇮🇳',
    digitGroups: [5, 5],
  );

  @override
  bool operator ==(Object other) =>
      other is Country && other.isoCode == isoCode;

  @override
  int get hashCode => isoCode.hashCode;
}
