import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/core/responsive/app_sizing.dart';
import 'package:consultation_app/features/payment/domain/entities/payment_failure.dart';
import 'package:consultation_app/features/payment/presentation/screens/payment_failed_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the outcome screen on top of a stand-in route, so a pop has somewhere
/// to go and its result can be read.
Future<PaymentFailureChoice?> _open(
  WidgetTester tester,
  PaymentFailedArgs args, {
  Future<void> Function()? then,
}) async {
  tester.view
    ..physicalSize = const Size(402, 874)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  PaymentFailureChoice? choice;

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => AppSizingScope(child: child!),
      initialRoute: AppRoutes.home,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                choice = await Navigator.of(context).push<PaymentFailureChoice>(
                  MaterialPageRoute(
                    builder: (_) => PaymentFailedScreen(args: args),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  if (then != null) await then();
  return choice;
}

void main() {
  group('which failure a payment error amounts to', () {
    test('a closed sheet is a cancellation, and safe to retry', () {
      final reason = PaymentFailureReason.from(
        const Failure('closed', code: 'payment_cancelled'),
      );

      expect(reason, PaymentFailureReason.cancelled);
      expect(reason.isCharged, isFalse);
      expect(reason.canRetry, isTrue);
    });

    test('an unconfirmed payment is never offered a retry', () {
      // The one case where paying again charges twice. Matched on the code,
      // so rewording the sentence cannot turn it into a retryable failure.
      final reason = PaymentFailureReason.from(
        const Failure('reworded one day', code: 'payment_unconfirmed'),
      );

      expect(reason, PaymentFailureReason.unconfirmed);
      expect(reason.canRetry, isFalse);
      expect(reason.isCharged, isTrue);
    });

    test('a slot somebody else took is not charged and not retried', () {
      final reason = PaymentFailureReason.from(
        const Failure('taken', code: 'slot_taken'),
      );

      expect(reason, PaymentFailureReason.slotUnavailable);
      expect(reason.isCharged, isFalse);
      // Retrying the same slot can only fail again — a new time is the answer.
      expect(reason.canRetry, isFalse);
    });

    test('anything unrecognised reads as a decline', () {
      expect(
        PaymentFailureReason.from(const Failure('the bank said no')),
        PaymentFailureReason.declined,
      );
      expect(
        PaymentFailureReason.from(const Failure.network()),
        PaymentFailureReason.declined,
      );
    });

    test('only the paid-then-unfulfilled cases talk about a refund', () {
      for (final reason in PaymentFailureReason.values) {
        final expected = switch (reason) {
          PaymentFailureReason.unconfirmed ||
          PaymentFailureReason.noDoctor ||
          PaymentFailureReason.withdrawn => true,
          _ => false,
        };

        expect(reason.isCharged, expected, reason: reason.name);
      }
    });
  });

  group('PaymentFailedScreen', () {
    for (final reason in PaymentFailureReason.values) {
      testWidgets('${reason.name} lays out and answers the money question', (
        tester,
      ) async {
        await _open(
          tester,
          PaymentFailedArgs(
            reason: reason,
            doctorName: 'Dr. Samitha Thevar',
            formattedTotal: '₹750',
          ),
        );

        expect(tester.takeException(), isNull);

        // Every outcome says, in so many words, whether money left the
        // account. It is the question a failed payment raises first.
        if (reason.isCharged) {
          expect(
            find.textContaining(RegExp('refund', caseSensitive: false)),
            findsWidgets,
          );
        } else {
          expect(find.textContaining('not been charged'), findsOneWidget);
        }

        expect(
          find.text('Try again'),
          reason.canRetry ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('Try again hands the choice back to the payment screen', (
      tester,
    ) async {
      PaymentFailureChoice? choice;

      await _open(
        tester,
        const PaymentFailedArgs(
          reason: PaymentFailureReason.declined,
          doctorName: 'Dr. Samitha Thevar',
        ),
        then: () async {
          await tester.tap(find.text('Try again'));
          await tester.pumpAndSettle();
        },
      ).then((value) => choice = value);

      expect(find.byType(PaymentFailedScreen), findsNothing);
      expect(choice, PaymentFailureChoice.retry);
    });

    testWidgets('an unconfirmed payment tells them not to pay again', (
      tester,
    ) async {
      await _open(
        tester,
        const PaymentFailedArgs(
          reason: PaymentFailureReason.unconfirmed,
          doctorName: 'Dr. Samitha Thevar',
          formattedTotal: '₹750',
        ),
      );

      expect(find.textContaining('do not pay again'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a refund names the amount', (tester) async {
      await _open(
        tester,
        const PaymentFailedArgs(
          reason: PaymentFailureReason.noDoctor,
          doctorName: 'Dr. Samitha Thevar',
          formattedTotal: '₹750',
        ),
      );

      // "₹750 is being refunded" can be checked against a statement; "your
      // payment" cannot.
      expect(find.textContaining('₹750 is being refunded'), findsOneWidget);
    });

    testWidgets('the back gesture never means try again', (tester) async {
      PaymentFailureChoice? choice;

      await _open(
        tester,
        const PaymentFailedArgs(
          reason: PaymentFailureReason.declined,
          doctorName: 'Dr. Samitha Thevar',
        ),
        then: () async {
          final state = tester.state<NavigatorState>(find.byType(Navigator));
          await state.maybePop();
          await tester.pumpAndSettle();
        },
      ).then((value) => choice = value);

      // A gesture is not a decision to spend money.
      expect(choice, isNot(PaymentFailureChoice.retry));
    });
  });
}
