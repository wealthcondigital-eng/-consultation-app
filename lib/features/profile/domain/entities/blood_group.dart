/// A patient's blood group, as recorded on their profile.
enum BloodGroup {
  aPositive('a_positive', 'A+', 'A Positive (A+)'),
  aNegative('a_negative', 'A-', 'A Negative (A-)'),
  bPositive('b_positive', 'B+', 'B Positive (B+)'),
  bNegative('b_negative', 'B-', 'B Negative (B-)'),
  abPositive('ab_positive', 'AB+', 'AB Positive (AB+)'),
  abNegative('ab_negative', 'AB-', 'AB Negative (AB-)'),
  oPositive('o_positive', 'O+', 'O Positive (O+)'),
  oNegative('o_negative', 'O-', 'O Negative (O-)');

  const BloodGroup(this.key, this.shortLabel, this.label);

  /// Stable identifier used for persistence.
  final String key;

  /// `O+` — for a tight space such as a chip.
  final String shortLabel;

  /// `O Positive (O+)` — how the profile spells it out, so it cannot be
  /// misread in a clinical context.
  final String label;

  static BloodGroup? fromKey(String? key) {
    for (final group in BloodGroup.values) {
      if (group.key == key) return group;
    }
    return null;
  }
}
