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
  });
}
