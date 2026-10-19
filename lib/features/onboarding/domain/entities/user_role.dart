/// Which journey the user takes through the app.
enum UserRole {
  patient('patient', 'Patient'),
  doctor('doctor', 'Doctor');

  const UserRole(this.key, this.label);

  /// Stable identifier used for persistence and analytics.
  final String key;

  /// Human-readable name shown in the UI.
  final String label;

  static UserRole? fromKey(String? key) {
    for (final role in UserRole.values) {
      if (role.key == key) return role;
    }
    return null;
  }
}
