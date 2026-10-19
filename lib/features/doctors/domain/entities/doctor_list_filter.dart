import 'doctor.dart';

/// How the doctor listing is narrowed or ordered.
///
/// The design presents these as one single-select chip row, so filtering and
/// sorting share a selector rather than being separate controls.
enum DoctorListFilter {
  all('All'),
  availableNow('Available Now'),
  feeLowToHigh('Fee: Low to High');

  const DoctorListFilter(this.label);

  final String label;

  /// Applies this filter's narrowing and ordering to [doctors].
  List<Doctor> apply(List<Doctor> doctors) {
    final result = switch (this) {
      DoctorListFilter.availableNow =>
        doctors.where((doctor) => doctor.isAvailableNow).toList(),
      _ => List<Doctor>.of(doctors),
    };

    if (this == DoctorListFilter.feeLowToHigh) {
      result.sort((a, b) => a.consultationFee.compareTo(b.consultationFee));
    }

    return result;
  }
}
