import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  group('NumberFormattingService', () {
    final service = NumberFormattingService(localeConfig: LocaleNumberConfig.dotDecimal);
    final scaleFactor = BigInt.from(10).pow(NumberFormattingService.decimals);

    group('formatBalance', () {
      test('formats zero balance', () {
        expect(service.formatBalance(BigInt.zero), '0');
      });

      test('formats balance less than 1 unit', () {
        final balance = BigInt.parse('500000000000'); // 0.5
        expect(service.formatBalance(balance), '0.5');
        expect(service.formatBalance(balance, smartDecimals: 1), '0.5');
      });

      test('smart decimals test', () {
        final balance = BigInt.parse('1000010000000'); // 1.00001
        expect(service.formatBalance(balance, smartDecimals: 4, maxDecimals: 12), '1');
      });

      test('formats balance with exactly max decimals', () {
        final balance = BigInt.parse('1234500000000'); // 1.2345
        expect(service.formatBalance(balance, smartDecimals: 4), '1.2345');
        expect(service.formatBalance(balance, smartDecimals: 5), '1.2345'); // No trailing zeros
      });

      test('formats balance with more decimals than max (truncates display)', () {
        final balance = BigInt.parse('1234567800000'); // 1.2345678
        expect(service.formatBalance(balance, smartDecimals: 4), '1.2345');
        expect(service.formatBalance(balance, smartDecimals: 2), '1.23');
        expect(service.formatBalance(balance, smartDecimals: 0), '1');
      });

      test('formats balance with fewer decimals than max', () {
        final balance = BigInt.parse('1200000000000'); // 1.2
        expect(service.formatBalance(balance, smartDecimals: 4), '1.2');
        expect(service.formatBalance(balance, smartDecimals: 1), '1.2');
      });

      test('formats large balance', () {
        final balance = BigInt.parse('1234567890123000000000'); // 1,234,567,890.123
        expect(service.formatBalance(balance, smartDecimals: 3), '1,234,567,890.123');
        expect(service.formatBalance(balance, smartDecimals: 4), '1,234,567,890.123');
      });

      test('formats large balance without decimals', () {
        final balance = BigInt.parse('1234567890000000000000'); // 1,234,567,890
        expect(service.formatBalance(balance, smartDecimals: 0), '1,234,567,890');
      });

      test('formats minimal decimal value', () {
        final balance = BigInt.one; // 0.000000000001
        expect(service.formatBalance(balance, smartDecimals: 12), '0.000000000001');
        // Raising the cap reveals the significant digit instead of showing "0".
        expect(service.formatBalance(balance, smartDecimals: 4, maxDecimals: 12), '0.000000000001');
        // Below the absolute cap there is nothing to show.
        expect(service.formatBalance(balance, smartDecimals: 4), '0');
      });

      test('extends precision for small amounts that would round to zero', () {
        expect(service.formatBalance(BigInt.parse('100000000'), smartDecimals: 2), '0.0001'); // 0.0001
        expect(service.formatBalance(BigInt.parse('120000000'), smartDecimals: 2), '0.00012'); // 0.00012
        expect(service.formatBalance(BigInt.parse('987650000'), smartDecimals: 2), '0.00098'); // keeps 2 sig figs
      });

      test('never extends beyond the absolute maxDecimals cap', () {
        expect(service.formatBalance(BigInt.parse('1000000'), smartDecimals: 2), '0.000001'); // 1e-6, at cap
        expect(service.formatBalance(BigInt.parse('100000'), smartDecimals: 2), '0'); // 1e-7, below cap
        expect(service.formatBalance(BigInt.parse('100000'), smartDecimals: 2, maxDecimals: 9), '0.0000001');
      });

      test('does not extend when smartDecimals already shows a significant digit', () {
        final balance = BigInt.parse('500000000000'); // 0.5
        expect(service.formatBalance(balance, smartDecimals: 2), '0.5');
      });
    });

    group('parseAmount', () {
      test('parses integer string', () {
        expect(service.parseAmount('1'), scaleFactor);
        expect(service.parseAmount('123'), scaleFactor * BigInt.from(123));
      });

      test('parses decimal string', () {
        expect(service.parseAmount('1.2345'), BigInt.parse('1234500000000'));
        expect(service.parseAmount('0.5'), BigInt.parse('500000000000'));
      });

      test('parses decimal string with max decimals', () {
        expect(service.parseAmount('1.123456789'), BigInt.parse('1123456789000'));
      });

      test('parses decimal string exceeding max decimals (truncates)', () {
        expect(service.parseAmount('1.123456789999999'), BigInt.parse('1123456789999'));
      });

      test('parses string starting with decimal point, roundtrip test', () {
        final zeroPointFiveString12Digits = '500000000000';
        expect(service.parseAmount('.5'), BigInt.parse(zeroPointFiveString12Digits));
        expect(service.formatBalance(BigInt.parse(zeroPointFiveString12Digits)), '0.5');
      });

      test('returns zero for empty string', () {
        expect(service.parseAmount(''), BigInt.zero);
      });

      test('returns null for invalid string', () {
        expect(service.parseAmount('abc'), isNull);
        expect(service.parseAmount('1.2.3'), isNull);
        expect(service.parseAmount('--5'), isNull);
      });
    });

    group('formatWireAmount / parseWireAmount', () {
      test('formatWireAmount always uses dot decimal without grouping', () {
        final commaService = NumberFormattingService(localeConfig: LocaleNumberConfig.commaDecimal);
        final balance = BigInt.parse('1500000000000');
        expect(commaService.formatWireAmount(balance), '1.5');
      });

      test('round-trips canonical wire amounts', () {
        final balance = BigInt.parse('1500000000000');
        final wire = service.formatWireAmount(balance);
        expect(wire, '1.5');
        expect(service.parseWireAmount(wire), balance);
      });

      test('parses legacy comma-decimal amounts', () {
        expect(service.parseWireAmount('1,5'), BigInt.parse('1500000000000'));
      });

      test('parses legacy dot-decimal amounts', () {
        expect(service.parseWireAmount('1.5'), BigInt.parse('1500000000000'));
      });

      test('parses integer amounts', () {
        expect(service.parseWireAmount('1000'), scaleFactor * BigInt.from(1000));
      });

      test('parses mixed separators using rightmost decimal mark', () {
        expect(service.parseWireAmount('1.000,50'), BigInt.parse('1000500000000000'));
        expect(service.parseWireAmount('1,000.50'), BigInt.parse('1000500000000000'));
      });

      test('returns zero for empty wire amount', () {
        expect(service.parseWireAmount(''), BigInt.zero);
      });
    });
  });
}
