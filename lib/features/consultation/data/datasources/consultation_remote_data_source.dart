import '../../domain/entities/consult_option.dart';

/// Supplies the consultation options and the live wait estimate.
abstract interface class ConsultationRemoteDataSource {
  Future<List<ConsultOption>> fetchConsultOptions();
}

/// Sample content until the scheduling API exists. Swap for an HTTP
/// implementation — nothing above this layer changes.
class FakeConsultationRemoteDataSource implements ConsultationRemoteDataSource {
  const FakeConsultationRemoteDataSource();

  @override
  Future<List<ConsultOption>> fetchConsultOptions() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    return const [
      ConsultOption(
        kind: ConsultOptionKind.instant,
        title: 'Instant Consultation',
        description:
            'Connect instantly with the next available general '
            'physician for urgent symptoms, guidance, or prescriptions.',
        actionLabel: 'Connect Now',
        // The real endpoint returns the current queue depth as a wait.
        estimatedWait: Duration(minutes: 4),
      ),
      ConsultOption(
        kind: ConsultOptionKind.scheduled,
        title: 'Scheduled Consultation',
        description:
            'Schedule a detailed video call appointment with highly '
            'rated specialists or your family doctor at your convenience.',
        actionLabel: 'Book Appointment',
        note: 'Book slots for later today or tomorrow',
      ),
    ];
  }
}
