import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/services/deep_link_service.dart';

void main() {
  group('DeepLinkService /pay handling', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    void handle(String url) {
      container.read(deepLinkServiceProvider).handleLink(Uri.parse(url));
    }

    test('drops a /pay link with a malformed recipient', () {
      handle('https://www.quantus.com/pay?to=not-a-valid-address&amount=1.5');

      expect(container.read(paymentIntentProvider), isNull);
    });

    test('drops a /pay link with an invalid-checksum recipient', () {
      // One character off from a valid address — must fail SS58 validation.
      handle('https://www.quantus.com/pay?to=qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEdX&amount=1.5');

      expect(container.read(paymentIntentProvider), isNull);
    });

    test('drops a /pay link with a missing recipient', () {
      handle('https://www.quantus.com/pay?amount=1.5');

      expect(container.read(paymentIntentProvider), isNull);
    });

    test('drops a /pay link with a missing amount', () {
      handle('https://www.quantus.com/pay?to=qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda');

      expect(container.read(paymentIntentProvider), isNull);
    });

    test('ignores unrelated links', () {
      handle('https://www.quantus.com/unknown?to=whatever&amount=1');

      expect(container.read(paymentIntentProvider), isNull);
    });

    test('survives malformed percent-escapes instead of throwing at the caller', () {
      // handleLink runs inside the app_links stream listener, where a
      // FormatException from lazy percent-decoding has no handler.
      for (final url in [
        'https://www.quantus.com/account?id=%ff',
        'https://www.quantus.com/%ff%fe/account',
        'https://www.quantus.com/pay?to=%c3%28&amount=1.5',
        'https://www.quantus.com/pay/%ff',
      ]) {
        expect(() => handle(url), returnsNormally, reason: url);
      }

      expect(container.read(paymentIntentProvider), isNull);
      expect(container.read(sharedAccountIntentProvider), isNull);
    });
  });
}
