/// Gender as recorded on a patient's medical profile.
enum Gender {
  female('female', 'Female'),
  male('male', 'Male'),
  other('other', 'Other'),
  undisclosed('undisclosed', 'Prefer not to say');

  const Gender(this.key, this.label);

  /// Stable identifier used for persistence.
  final String key;

  final String label;

  static Gender? fromKey(String? key) {
    for (final gender in Gender.values) {
      if (gender.key == key) return gender;
    }
    return null;
  }
}
