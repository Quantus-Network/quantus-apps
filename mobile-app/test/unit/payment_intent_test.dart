import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';

void main() {
  group('PaymentIntent.tryParseUrl', () {
    test('parses a valid /pay link', () {
      final intent = PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient&amount=1.5&ref=order-1');

      expect(intent, isNotNull);
      expect(intent!.to, 'recipient');
      expect(intent.amount, '1.5');
      expect(intent.ref, 'order-1');
    });

    test('ref is optional', () {
      final intent = PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient&amount=1.5');

      expect(intent, isNotNull);
      expect(intent!.ref, isNull);
    });

    test('returns null when to is missing', () {
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?amount=1.5'), isNull);
    });

    test('returns null when to is empty', () {
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=&amount=1.5'), isNull);
    });

    test('returns null when amount is missing', () {
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient'), isNull);
    });

    test('returns null when amount is empty', () {
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient&amount='), isNull);
    });

    test('returns null for a non-pay path', () {
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/account?id=abc'), isNull);
    });

    test('returns null for a malformed url', () {
      expect(PaymentIntent.tryParseUrl(':::'), isNull);
    });

    test('rejects exponent notation in amount', () {
      // Immunefi regression: amount=1e10000000 froze the wallet materialising
      // an unbounded BigInt on the UI isolate.
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient&amount=1e10000000'), isNull);
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient&amount=1E5'), isNull);
    });

    test('rejects non-scheme amount shapes', () {
      // Wire amounts are NNN[.NNN], dot separator only.
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient&amount=1,5'), isNull);
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient&amount=-1'), isNull);
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient&amount=.5'), isNull);
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient&amount=1.1234567890123'), isNull);
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient&amount=1.25'), isNotNull);
    });

    test('rejects over-long input', () {
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient&amount=${'9' * 100}'), isNull);
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=${'a' * 65}&amount=1.5'), isNull);
      expect(PaymentIntent.tryParseUrl('https://www.quantus.com/pay?to=recipient&amount=1.5&ref=${'r' * 65}'), isNull);
    });

    test('accepts a maximal valid link', () {
      final intent = PaymentIntent.tryParseUrl(
        'https://www.quantus.com/pay?to=${'a' * 50}&amount=12345678901234567890.123456789012&ref=${'r' * 64}',
      );

      expect(intent, isNotNull);
      expect(intent!.amount, '12345678901234567890.123456789012');
      expect(intent.ref, 'r' * 64);
    });
  });
}
