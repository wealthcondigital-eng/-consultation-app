import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';

/// One person this doctor has consulted.
///
/// **Anonymous consultations never appear here.** Grouping them by the account
/// behind the alias would tell the doctor that two aliases are one patient,
/// which is the single thing an anonymous consultation promises not to say.
/// They stay on the appointment list under the alias, individually, which is
/// what the patient agreed to.
class DoctorPatient {
  const DoctorPatient({
    required this.id,
    required this.name,
    required this.consultations,
    required this.lastConsultedAt,
    required this.lastMode,
    this.billed = 0,
  });

  /// The patient's account id — what a row taps through on.
  final String id;

  final String name;

  /// How many consultations this doctor has had with them.
  final int consultations;

  final DateTime lastConsultedAt;
  final ConsultationMode lastMode;

  /// What they have been charged by **this** doctor, in whole rupees, over
  /// completed consultations. The pair's billing history, not the patient's
  /// total spend — a doctor has no business seeing what someone paid elsewhere.
  final int billed;

  /// `3 consultations` / `1 consultation`
  String get consultationsLabel => consultations == 1
      ? tr('1 consultation')
      : tr('{count} consultations', {'count': consultations});

  /// `Last seen Sep 9, 2026`
  String get lastSeenLabel => tr('Last seen {date}', {
    'date': AppDateFormat.monthDayYear(lastConsultedAt),
  });

  /// `₹1,800` — grouped, because a roster of four-figure totals is unreadable
  /// otherwise.
  String get billedLabel => '₹${_grouped(billed)}';

  /// `12345` → `12,345`. Indian grouping — the first comma after three digits
  /// and every two after that, which is how a rupee amount is read here.
  static String _grouped(int amount) {
    final digits = amount.toString();
    if (digits.length <= 3) return digits;

    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);

    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);

    return '${groups.join(',')},$last3';
  }
}
