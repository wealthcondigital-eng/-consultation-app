import 'package:consultation_app/features/consultation/data/datasources/consultation_remote_data_source.dart';
import 'package:consultation_app/features/consultation/data/repositories/consultation_repository_impl.dart';
import 'package:consultation_app/features/consultation/domain/entities/consult_option.dart';
import 'package:consultation_app/features/consultation/domain/usecases/get_consult_options.dart';
import 'package:flutter_test/flutter_test.dart';

ConsultOption _option({Duration? wait}) {
  return ConsultOption(
    kind: ConsultOptionKind.instant,
    title: 'Instant Consultation',
    description: 'Connect instantly.',
    actionLabel: 'Connect Now',
    estimatedWait: wait,
  );
}

void main() {
  group('ConsultOption', () {
    test('formats a multi-minute wait', () {
      expect(
        _option(wait: const Duration(minutes: 4)).estimatedWaitLabel,
        'Estimated Wait: ~4 mins',
      );
    });

    test('uses the singular for one minute', () {
      expect(
        _option(wait: const Duration(minutes: 1)).estimatedWaitLabel,
        'Estimated Wait: ~1 min',
      );
    });

    test('has wording for a sub-minute wait rather than "~0 mins"', () {
      expect(
        _option(wait: const Duration(seconds: 20)).estimatedWaitLabel,
        'Estimated Wait: under a minute',
      );
    });

    test('has no wait label when there is no wait to quote', () {
      expect(_option().estimatedWaitLabel, isNull);
    });
  });

  group('GetConsultOptions', () {
    test('returns an immediate and a scheduled option', () async {
      final options = await GetConsultOptions(
        ConsultationRepositoryImpl(const FakeConsultationRemoteDataSource()),
      )();

      expect(options, hasLength(2));
      expect(options.first.kind, ConsultOptionKind.instant);
      expect(options.first.estimatedWait, isNotNull);
      expect(options.last.kind, ConsultOptionKind.scheduled);
      expect(options.last.note, isNotNull);
    });
  });
}
