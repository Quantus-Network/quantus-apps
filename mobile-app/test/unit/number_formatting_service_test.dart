import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  group('NumberFormattingService', () {
    final service = NumberFormattingService();
    final scaleFactor = BigInt.from(10).pow(NumberFormattingService.decimals);

    group('formatBalance', () {
      test('formats zero balance', () {
        expect(service.formatBalance(BigInt.zero), '0');
      });

      test('formats balance less than 1 unit', () {
        final balance = BigInt.parse('500000000000'); // 0.5
        expect(service.formatBalance(balance), '0.5');
        expect(service.formatBalance(balance, maxDecimals: 1), '0.5');
      });

      test('formats balance with exactly max decimals', () {
        final balance = BigInt.parse('1234500000000'); // 1.2345
        expect(service.formatBalance(balance, maxDecimals: 4), '1.2345');
        expect(service.formatBalance(balance, maxDecimals: 5), '1.2345'); // No trailing zeros
      });

      test('formats balance with more decimals than max (rounds display)', () {
        final balance = BigInt.parse('1234567800000'); // 1.2345678
        expect(service.formatBalance(balance, maxDecimals: 4), '1.2346');
        expect(service.formatBalance(balance, maxDecimals: 2), '1.23');
        expect(service.formatBalance(balance, maxDecimals: 0), '1');
      });

      test('formats balance with fewer decimals than max', () {
        final balance = BigInt.parse('1200000000000'); // 1.2
        expect(service.formatBalance(balance, maxDecimals: 4), '1.2');
        expect(service.formatBalance(balance, maxDecimals: 1), '1.2');
      });

      test('formats large balance', () {
        final balance = BigInt.parse('1234567890123000000000'); // 1,234,567,890.123
        // Current formatBalance doesn't add grouping separators, update if needed
        expect(service.formatBalance(balance, maxDecimals: 3), '1,234,567,890.123');
        expect(service.formatBalance(balance, maxDecimals: 4), '1,234,567,890.123');
      });

      test('formats large balance without decimals', () {
        final balance = BigInt.parse('1234567890000000000000'); // 1,234,567,890
        expect(service.formatBalance(balance, maxDecimals: 0), '1,234,567,890');
      });

      test('formats minimal decimal value', () {
        final balance = BigInt.one; // 0.000000000001
        expect(service.formatBalance(balance, maxDecimals: 12), '0.000000000001');
        expect(service.formatBalance(balance, maxDecimals: 4), '0'); // Truncates to 0
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
  });
}
