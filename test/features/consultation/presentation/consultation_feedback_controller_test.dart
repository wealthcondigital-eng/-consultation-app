import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/consultation/domain/entities/live_consultation.dart';
import 'package:consultation_app/features/consultation/domain/repositories/consultation_session_repository.dart';
import 'package:consultation_app/features/consultation/domain/usecases/answer_consultations.dart';
import 'package:consultation_app/features/consultation/presentation/controllers/consultation_feedback_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the rating, so a test can assert what reached the API.
class _RecordingConsultations implements ConsultationSessionRepository {
  _RecordingConsultations({this.failure});

  final Failure? failure;

  String? id;
  int? rating;
  String? feedback;
  int? callQuality;
  List<String> tags = const [];
  int calls = 0;

  @override
  Future<void> rate(
    String id, {
    required int rating,
    String? feedback,
    int? callQuality,
    List<String> tags = const [],
  }) async {
    calls++;
    this.id = id;
    this.rating = rating;
    this.feedback = feedback;
    this.callQuality = callQuality;
    this.tags = tags;

    if (failure case final failure?) throw failure;
  }

  // --- Not used by the review path -----------------------------------------

  @override
  Future<LiveConsultation> requestInstant({
    required ConsultationMode mode,
    String? speciality,
    bool isAnonymous = false,
    String? alias,
    String? concern,
  }) => throw UnimplementedError();

  @override
  Future<LiveConsultation> schedule({
    required String doctorId,
    required ConsultationMode mode,
    required DateTime scheduledAt,
    String? concern,
    bool isAnonymous = false,
    String? alias,
  }) => throw UnimplementedError();

  @override
  Stream<LiveConsultation> watch(String id) => const Stream.empty();

  @override
  Stream<LiveConsultation?> watchIncoming() => const Stream.empty();

  @override
  Future<LiveConsultation> accept(String id) => throw UnimplementedError();

  @override
  Future<LiveConsultation> cancel(String id) => throw UnimplementedError();

  @override
  Future<LiveConsultation> decline(String id) => throw UnimplementedError();

  @override
  Future<LiveConsultation> end(String id) => throw UnimplementedError();

  @override
  Future<LiveConsultation> join(String id) => throw UnimplementedError();
}

ConsultationFeedbackController _controller(_RecordingConsultations rated) {
  return ConsultationFeedbackController(ManageConsultationCall(rated));
}

void main() {
  group('ConsultationFeedbackController', () {
    test('will not submit without stars', () {
      final controller = _controller(_RecordingConsultations());
      addTearDown(controller.dispose);

      // The note and the chips are optional; the rating is the thing being
      // asked for.
      expect(controller.canSubmit, isFalse);

      controller.rateDoctor(4);
      expect(controller.canSubmit, isTrue);
    });

    test('stores the review, which is what puts it on the profile', () async {
      // The screen used to end at a `TODO`: the stars were drawn, the chips
      // were tapped, Submit went home, and nothing was written anywhere. Every
      // review a patient left was discarded, which is why no doctor's profile
      // had one.
      final rated = _RecordingConsultations();
      final controller = _controller(rated);
      addTearDown(controller.dispose);

      controller
        ..rateDoctor(5)
        ..rateCallQuality(3)
        ..toggleExperience('Good Listener')
        ..changeNote('  Explained everything clearly.  ');

      final stored = await controller.submit('consultation-1');

      expect(stored, isTrue);
      expect(rated.calls, 1);
      expect(rated.id, 'consultation-1');
      expect(rated.rating, 5);
      expect(rated.feedback, 'Explained everything clearly.');
      expect(rated.callQuality, 3);
      expect(rated.tags, ['Good Listener']);
    });

    test(
      'an unanswered call quality is sent as nothing, not as one star',
      () async {
        // Different claims. One star on the connection is a complaint; no answer
        // is no answer.
        final rated = _RecordingConsultations();
        final controller = _controller(rated);
        addTearDown(controller.dispose);

        controller.rateDoctor(4);
        await controller.submit('consultation-1');

        expect(rated.callQuality, isNull);
        expect(rated.tags, isEmpty);
      },
    );

    test('an empty note is sent as nothing', () async {
      final rated = _RecordingConsultations();
      final controller = _controller(rated);
      addTearDown(controller.dispose);

      controller
        ..rateDoctor(4)
        ..changeNote('   ');
      await controller.submit('consultation-1');

      expect(rated.feedback, isNull);
    });

    test('a chip can be turned off again', () {
      final controller = _controller(_RecordingConsultations());
      addTearDown(controller.dispose);

      controller.toggleExperience('Friendly');
      expect(controller.isSelected('Friendly'), isTrue);

      controller.toggleExperience('Friendly');
      expect(controller.isSelected('Friendly'), isFalse);
    });

    test('a failed write keeps the patient on the screen', () async {
      // This is the only moment somebody is willing to write a review —
      // the call has just ended and they are still holding the phone. Sending
      // them home on an error would lose it with nothing said.
      final rated = _RecordingConsultations(
        failure: const Failure('No connection.'),
      );
      final controller = _controller(rated);
      addTearDown(controller.dispose);

      controller.rateDoctor(5);
      final stored = await controller.submit('consultation-1');

      expect(stored, isFalse);
      expect(controller.errorMessage, 'No connection.');
      expect(controller.doctorRating, 5);
    });
  });
}
