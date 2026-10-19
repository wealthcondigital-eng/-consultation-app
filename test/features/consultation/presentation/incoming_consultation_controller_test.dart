import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/consultation/domain/entities/live_consultation.dart';
import 'package:consultation_app/features/consultation/domain/repositories/consultation_session_repository.dart';
import 'package:consultation_app/features/consultation/domain/usecases/answer_consultations.dart';
import 'package:consultation_app/features/consultation/presentation/controllers/incoming_consultation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

LiveConsultation _consultation(String id, LiveConsultationStatus status) =>
    LiveConsultation(
      id: id,
      status: status,
      mode: ConsultationMode.video,
      channelId: 'consult-$id',
      peerId: 'doctor-peer',
      isCaller: false,
      patientName: 'Ravi Kumar',
    );

/// Answers accept with the call, or with [failure].
class _Consultations implements ConsultationSessionRepository {
  _Consultations({this.failure});

  final Failure? failure;
  final List<String> accepted = [];

  @override
  Future<LiveConsultation> accept(String id) async {
    accepted.add(id);
    if (failure case final failure?) throw failure;
    return _consultation(id, LiveConsultationStatus.accepted);
  }

  @override
  Stream<LiveConsultation?> watchIncoming() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('acceptById — an Accept from the phone’s ringing screen', () {
    test('accepts a call this poll never saw ring', () async {
      // The app was killed until a moment ago, so nothing has polled yet.
      final repository = _Consultations();
      final controller = IncomingConsultationController(
        AnswerConsultations(repository),
      );

      await controller.acceptById('c_1');

      expect(repository.accepted, ['c_1']);
      expect(controller.takeAccepted()?.id, 'c_1');
      expect(controller.errorMessage, isNull);
    });

    test('says why when the ring has already moved on', () async {
      final controller = IncomingConsultationController(
        AnswerConsultations(
          _Consultations(
            failure: const Failure('That consultation is no longer waiting.'),
          ),
        ),
      );

      await controller.acceptById('c_1');

      expect(controller.takeAccepted(), isNull);
      expect(
        controller.errorMessage,
        'That consultation is no longer waiting.',
      );
      expect(controller.isAnswering, isFalse);
    });
  });
}
