/// What the setup form's dropdowns offer.
///
/// Supplied by the backend rather than hard-coded in the widgets: degrees and
/// specialities change, and cities depend on the state.
class DoctorSetupOptions {
  const DoctorSetupOptions({
    this.degrees = const [],
    this.specialities = const [],
    this.citiesByState = const {},
    this.experienceYears = const [],
  });

  final List<String> degrees;
  final List<String> specialities;

  /// State name to the cities the app lists for it.
  final Map<String, List<String>> citiesByState;

  final List<int> experienceYears;

  List<String> get states => citiesByState.keys.toList();

  /// The cities for [state], or empty until one is chosen.
  List<String> citiesIn(String? state) =>
      state == null ? const [] : citiesByState[state] ?? const [];
}
