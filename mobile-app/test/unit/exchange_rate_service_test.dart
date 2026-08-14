import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/services/exchange_rate_service.dart';

void main() {
  // 1 token = 1 USD; 1 USD = 3.97 MYR, 17334 IDR (zero-decimal currency).
  final rates = {'USD': Decimal.parse('1'), 'MYR': Decimal.parse('3.97'), 'IDR': Decimal.parse('17334')};

  late ExchangeRateService service;

  setUp(() {
    service = ExchangeRateService(rates: rates);
  });

  group('ExchangeRateService.getRate', () {
    test('returns the rate for a known currency', () {
      expect(service.getRate(FiatCurrency.usd), Decimal.one);
      expect(service.getRate(FiatCurrency.myr), Decimal.parse('3.97'));
    });

    test('falls back to fallbackRates for a missing live rate', () {
      final serviceWithEmpty = ExchangeRateService(rates: {});
      expect(serviceWithEmpty.getRate(FiatCurrency.usd), ExchangeRateService.fallbackRates['USD']);
    });
  });

  group('ExchangeRateService.convert', () {
    test('converts 1 token to USD correctly (1 token = 1 USD)', () {
      expect(service.convert(Decimal.one, FiatCurrency.usd), Decimal.one);
    });

    test('converts 1 token to MYR (1 token = 4 MYR)', () {
      expect(service.convert(Decimal.one, FiatCurrency.myr), Decimal.parse('3.97'));
    });

    test('converts 0.5 tokens to MYR (0.5 × 3.97 = 1.99)', () {
      expect(service.convert(Decimal.parse('0.5'), FiatCurrency.myr), Decimal.parse('1.99'));
    });

    test('applies tokenToUsdRate when set', () {
      final serviceWith2xRate = ExchangeRateService(rates: rates, tokenToUsdRate: Decimal.parse('2'));
      // 1 token × 2 USD/token × 3.97 MYR/USD = 7.94 MYR
      expect(serviceWith2xRate.convert(Decimal.one, FiatCurrency.myr), Decimal.parse('7.94'));
    });
  });

  group('ExchangeRateService.tokenToFiat', () {
    // 12 decimal places (AppConstants.decimals)
    const tokenDecimals = 12;
    final oneToken = BigInt.from(10).pow(tokenDecimals); // 1.000000000000 tokens

    test('1 token → 1.00 USD', () {
      expect(service.tokenToFiat(oneToken, FiatCurrency.usd, tokenDecimals), Decimal.one);
    });

    test('1 token → 3.97 MYR', () {
      expect(service.tokenToFiat(oneToken, FiatCurrency.myr, tokenDecimals), Decimal.parse('3.97'));
    });

    test('0.5 tokens → 1.99 MYR', () {
      final halfToken = BigInt.from(5) * BigInt.from(10).pow(tokenDecimals - 1);
      expect(service.tokenToFiat(halfToken, FiatCurrency.myr, tokenDecimals), Decimal.parse('1.99'));
    });

    test('zero tokens → zero fiat', () {
      expect(service.tokenToFiat(BigInt.zero, FiatCurrency.usd, tokenDecimals), Decimal.zero);
    });
  });

  group('ExchangeRateService.fiatToToken', () {
    const tokenDecimals = 12;
    final oneToken = BigInt.from(10).pow(tokenDecimals);

    test('1 USD → 1 token', () {
      expect(service.fiatToToken(Decimal.one, FiatCurrency.usd, tokenDecimals), oneToken);
    });

    test('3.97 MYR → 1 token', () {
      expect(service.fiatToToken(Decimal.parse('3.97'), FiatCurrency.myr, tokenDecimals), oneToken);
    });

    test('1.985 MYR → 0.5 tokens', () {
      final halfToken = BigInt.from(5) * BigInt.from(10).pow(tokenDecimals - 1);
      expect(service.fiatToToken(Decimal.parse('1.985'), FiatCurrency.myr, tokenDecimals), halfToken);
    });

    test('zero fiat → zero tokens', () {
      expect(service.fiatToToken(Decimal.zero, FiatCurrency.usd, tokenDecimals), BigInt.zero);
    });

    test('tokenToFiat and fiatToToken are inverses for clean-divisor rates', () {
      const tokenDecimals = 12;
      final original = BigInt.from(1_000_000_000_000); // 1.0 tokens
      final fiatValue = service.tokenToFiat(original, FiatCurrency.myr, tokenDecimals);
      final roundTripped = service.fiatToToken(fiatValue, FiatCurrency.myr, tokenDecimals);
      expect(roundTripped, original);
    });

    test('round-trip is stable for non-clean-divisor rates (anchors to fiat precision)', () {
      // 3.971 doesn't cleanly divide 1.5 tokens's fiat value.
      // By rounding the intermediate fiat value to fiat.decimals (2),
      // we ensure that the round-tripped tokens value is the canonical tokens
      // representation of that specific fiat amount.
      const tokenDecimals = 12;
      final lossyService = ExchangeRateService(rates: {'MYR': Decimal.parse('3.971')});
      final original = BigInt.from(1_500_000_000_000); // 1.5 tokens

      // 1.5 * 3.971 = 5.9565 -> rounded to 5.96 MYR
      final fiatValue = lossyService.tokenToFiat(original, FiatCurrency.myr, tokenDecimals);
      expect(fiatValue, Decimal.parse('5.96'));

      final roundTripped = lossyService.fiatToToken(fiatValue, FiatCurrency.myr, tokenDecimals);

      // Subsequent round-trips from this fiatValue should be identical
      final secondFiat = lossyService.tokenToFiat(roundTripped, FiatCurrency.myr, tokenDecimals);
      final secondToken = lossyService.fiatToToken(secondFiat, FiatCurrency.myr, tokenDecimals);

      expect(secondFiat, fiatValue);
      expect(secondToken, roundTripped);
    });
  });

  group('FiatCurrency.decimals', () {
    test('USD has 2 decimal places', () => expect(FiatCurrency.usd.decimals, 2));
    test('EUR has 2 decimal places', () => expect(FiatCurrency.eur.decimals, 2));
    test('GBP has 2 decimal places', () => expect(FiatCurrency.gbp.decimals, 2));
    test('MYR has 2 decimal places', () => expect(FiatCurrency.myr.decimals, 2));
    test('IDR has 0 decimal places', () => expect(FiatCurrency.idr.decimals, 0));
    test('JPY has 0 decimal places', () => expect(FiatCurrency.jpy.decimals, 0));
  });
}
