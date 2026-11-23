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

    group('formatCompactAmount', () {
      BigInt units(String amount, {int decimals = NumberFormattingService.decimals}) =>
          service.parseAmount(amount, decimals: decimals)!;
      String compact(String amount) => service.formatCompactAmount(units(amount));

      test('zero renders as 0', () {
        expect(service.formatCompactAmount(BigInt.zero), '0');
      });

      test('sub-unit amounts keep 4 decimals', () {
        expect(compact('0.024213'), '0.0242');
        expect(compact('0.5'), '0.5');
        expect(compact('0.0001'), '0.0001');
        expect(compact('0.99999'), '0.9999');
      });

      test('amounts below 0.0001 show a floor instead of a long tail', () {
        expect(compact('0.00001234'), '<0.0001');
        expect(compact('0.00009999'), '<0.0001');
        expect(compact('0.000000000001'), '<0.0001');
      });

      test('1 to 999 keep 4 significant digits, rounded down', () {
        expect(compact('1'), '1');
        expect(compact('1.23456'), '1.234');
        expect(compact('12.3456'), '12.34');
        expect(compact('999.99'), '999.9');
      });

      test('thousands use K with 4 significant digits', () {
        expect(compact('1234.5678'), '1.234K');
        expect(compact('12345'), '12.34K');
        expect(compact('123456'), '123.4K');
        expect(compact('1000'), '1K');
      });

      test('millions, billions and trillions use M, B and T', () {
        expect(compact('1234567'), '1.234M');
        expect(compact('2500000000'), '2.5B');
        expect(compact('3000000000000'), '3T');
      });

      test('never rounds up across a suffix boundary', () {
        expect(compact('999999'), '999.9K');
        expect(compact('999.99999'), '999.9');
      });

      test('uses the token decimals', () {
        expect(service.formatCompactAmount(units('1234.5678', decimals: 6), decimals: 6), '1.234K');
        expect(service.formatCompactAmount(units('0.024213', decimals: 6), decimals: 6), '0.0242');
        expect(service.formatCompactAmount(units('0.00001', decimals: 6), decimals: 6), '<0.0001');
      });

      test('uses the locale decimal separator', () {
        final comma = NumberFormattingService(localeConfig: LocaleNumberConfig.commaDecimal);
        expect(comma.formatCompactAmount(units('1234.5')), '1,234K');
        expect(comma.formatCompactAmount(units('0.0242')), '0,0242');
        expect(comma.formatCompactAmount(units('0.00001')), '<0,0001');
      });

      test('result is never longer than 7 characters', () {
        for (var exponent = -8; exponent <= 15; exponent++) {
          for (final mantissa in ['1', '1.5', '9.99999999']) {
            final amount =
                BigInt.parse(mantissa.replaceAll('.', '')) *
                BigInt.from(10).pow(NumberFormattingService.decimals + exponent) ~/
                BigInt.from(10).pow(mantissa.contains('.') ? mantissa.length - 2 : 0);
            final shown = service.formatCompactAmount(amount);
            expect(shown.length, lessThanOrEqualTo(7), reason: '${mantissa}e$exponent rendered as $shown');
          }
        }
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

      test('parses dot-decimal wire amounts', () {
        expect(service.parseWireAmount('1.5'), BigInt.parse('1500000000000'));
      });

      test('parses integer amounts', () {
        expect(service.parseWireAmount('1000'), scaleFactor * BigInt.from(1000));
      });

      test('rejects locale-formatted amounts — the wire format is locale-free', () {
        expect(service.parseWireAmount('1,5'), isNull);
        expect(service.parseWireAmount('1.000,50'), isNull);
        expect(service.parseWireAmount('1,000.50'), isNull);
        expect(service.parseWireAmount('1 000.5'), isNull);
        expect(service.parseWireAmount('.5'), isNull);
        expect(service.parseWireAmount('1.'), isNull);
      });

      test('returns zero for empty wire amount', () {
        expect(service.parseWireAmount(''), BigInt.zero);
      });

      test('rejects exponent notation and over-long input', () {
        // Regression test for the audit report: amount=1e10000000 in a /pay
        // deep link froze the wallet materialising an unbounded BigInt.
        expect(service.parseWireAmount('1e10000000'), isNull);
        expect(service.parseWireAmount('1e5'), isNull);
        expect(service.parseWireAmount('9' * 100), isNull);
        expect(service.parseWireAmount('1.25'), BigInt.parse('1250000000000'));
      });

      test('bounds whole digits by the supply cap', () {
        expect(service.parseWireAmount('9' * (AppConstants.maxWholeDigits + 1)), isNull);
        expect(service.parseWireAmount('20999999.999999999999'), BigInt.parse('20999999999999999999'));
      });
    });
    group('counts and hundredths', () {
      test('formatInteger groups thousands', () {
        expect(service.formatInteger(5279), '5,279');
        expect(service.formatInteger(7), '7');
      });

      test('formatHundredths always shows two decimals', () {
        expect(service.formatHundredths(6539), '65.39');
        expect(service.formatHundredths(10), '0.10');
        expect(service.formatHundredths(1218000, addSymbol: true), '12,180.00 ${AppConstants.tokenSymbol}');
      });
    });
  });
}
