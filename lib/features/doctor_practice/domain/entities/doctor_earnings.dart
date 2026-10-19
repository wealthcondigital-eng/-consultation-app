import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';

/// Which stretch of time the earnings screen is showing.
enum EarningsPeriod {
  today('Today'),

  /// The last seven days including today, not the calendar week: a doctor
  /// checking on a Monday wants the week they just worked, not the six hours
  /// since it started.
  week('7 days'),
  month('This month'),
  all('All time');

  const EarningsPeriod(this.label);

  final String label;

  /// The query value the API expects.
  String get query => name;
}

/// One bar on the earnings chart.
class EarningsBucket {
  const EarningsBucket({
    required this.key,
    required this.gross,
    required this.consultations,
  });

  /// `2026-09-11` for a day, `2026-09` for a month.
  final String key;

  final int gross;
  final int consultations;

  /// `Sep 11` for a day, `Sep 2026` for a month.
  ///
  /// Parsed rather than sent as a label, because how a date reads is the app's
  /// decision — the API sends a key and the app already formats dates.
  String get label {
    final parts = key.split('-');
    final year = int.tryParse(parts.elementAtOrNull(0) ?? '');
    final month = int.tryParse(parts.elementAtOrNull(1) ?? '');
    final day = int.tryParse(parts.elementAtOrNull(2) ?? '');

    if (year == null || month == null) return key;
    if (day == null) {
      return '${AppDateFormat.monthLabelAt(month - 1)} $year';
    }

    return AppDateFormat.dayMonth(DateTime(year, month, day));
  }
}

/// One completed consultation, as a line on the ledger.
class EarningsEntry {
  const EarningsEntry({
    required this.id,
    required this.patientName,
    required this.mode,
    required this.endedAt,
    required this.fee,
    this.durationSeconds = 0,
  });

  final String id;
  final String patientName;
  final ConsultationMode mode;
  final DateTime endedAt;

  /// In whole rupees, at the fee snapshotted when the doctor accepted — not
  /// their current fee. A doctor who raises their price today has not raised
  /// the price of last week's calls.
  final int fee;

  final int durationSeconds;

  /// `Sep 9 · 10:30 AM`
  String get whenLabel =>
      '${AppDateFormat.dayMonth(endedAt)} · ${AppDateFormat.clockTime(endedAt)}';

  /// `Video · 12 min`
  String get detailLabel {
    final mode = tr(this.mode.shortLabel);
    if (durationSeconds <= 0) return mode;

    final minutes = durationSeconds ~/ 60;
    final duration = minutes < 1
        ? tr('{seconds} sec', {'seconds': durationSeconds})
        : tr('{minutes} min', {'minutes': minutes});

    return '$mode · $duration';
  }

  String get feeLabel => '₹$fee';
}

/// What a doctor has earned over a period.
///
/// **Gross only, and deliberately so.** The platform's commission is not
/// deducted anywhere in this app or in the API, because no rate is configured
/// in the project. A percentage invented in code is a number a doctor would
/// plan against and then be paid less than; when finance sets one it belongs
/// in the API's configuration, and a net figure lands with it.
class DoctorEarnings {
  const DoctorEarnings({
    required this.period,
    this.gross = 0,
    this.consultations = 0,
    this.averageFee = 0,
    this.inFlight = 0,
    this.buckets = const [],
    this.entries = const [],
  });

  const DoctorEarnings.empty()
    : period = EarningsPeriod.month,
      gross = 0,
      consultations = 0,
      averageFee = 0,
      inFlight = 0,
      buckets = const [],
      entries = const [];

  final EarningsPeriod period;

  /// What patients were charged, in whole rupees, over completed consultations.
  final int gross;

  final int consultations;
  final int averageFee;

  /// Consultations not yet counted because they have not finished. Shown so a
  /// doctor mid-shift does not read today's figure as their whole day.
  final int inFlight;

  final List<EarningsBucket> buckets;
  final List<EarningsEntry> entries;

  bool get isEmpty => consultations == 0;

  /// `₹12,600`
  String get grossLabel => '₹${_grouped(gross)}';

  /// `₹700`
  String get averageFeeLabel =>
      consultations == 0 ? '—' : '₹${_grouped(averageFee)}';

  /// The tallest bar, for scaling the chart. At least one, so a period with no
  /// earnings divides safely rather than producing infinities.
  int get peak => buckets.fold(
    1,
    (highest, bucket) => bucket.gross > highest ? bucket.gross : highest,
  );

  /// Indian grouping — the first comma after three digits and every two after
  /// that, which is how a rupee amount is read here.
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
