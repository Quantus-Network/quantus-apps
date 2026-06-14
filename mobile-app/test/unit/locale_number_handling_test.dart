import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  group('LocaleNumberConfig', () {
    group('fromLocale factory', () {
      test('US locale uses dot decimal and comma grouping', () {
        final config = LocaleNumberConfig.fromLocale('en_US');
        expect(config.decimalSeparator, '.');
        expect(config.groupingSeparator, ',');
        expect(config.isCommaDecimal, false);
      });

      test('Indonesian locale uses comma decimal and dot grouping', () {
        final config = LocaleNumberConfig.fromLocale('id_ID');
        expect(config.decimalSeparator, ',');
        expect(config.groupingSeparator, '.');
        expect(config.isCommaDecimal, true);
      });

      test('German locale uses comma decimal and dot grouping', () {
        final config = LocaleNumberConfig.fromLocale('de_DE');
        expect(config.decimalSeparator, ',');
        expect(config.groupingSeparator, '.');
        expect(config.isCommaDecimal, true);
      });

      test('French locale uses comma decimal', () {
        final config = LocaleNumberConfig.fromLocale('fr_FR');
        expect(config.decimalSeparator, ',');
        expect(config.isCommaDecimal, true);
      });

      test('UK locale uses dot decimal and comma grouping', () {
        final config = LocaleNumberConfig.fromLocale('en_GB');
        expect(config.decimalSeparator, '.');
        expect(config.groupingSeparator, ',');
        expect(config.isCommaDecimal, false);
      });

      test('Japanese locale uses dot decimal', () {
        final config = LocaleNumberConfig.fromLocale('ja_JP');
        expect(config.decimalSeparator, '.');
        expect(config.isCommaDecimal, false);
      });

      test('Malaysian locale uses dot decimal', () {
        final config = LocaleNumberConfig.fromLocale('ms_MY');
        expect(config.decimalSeparator, '.');
        expect(config.isCommaDecimal, false);
      });
    });

    group('normalize', () {
      test('US locale: strips comma thousands, keeps dot decimal', () {
        const config = LocaleNumberConfig.dotDecimal;
        expect(config.normalize('1,000.50'), '1000.50');
        expect(config.normalize('1,000,000.99'), '1000000.99');
        expect(config.normalize('1,000'), '1000');
        expect(config.normalize('0.5'), '0.5');
        expect(config.normalize('100'), '100');
      });

      test('Indonesian locale: strips dot thousands, converts comma decimal', () {
        const config = LocaleNumberConfig.commaDecimal;
        expect(config.normalize('1.000,50'), '1000.50');
        expect(config.normalize('1.000.000,99'), '1000000.99');
        expect(config.normalize('1.000'), '1000');
        expect(config.normalize('0,5'), '0.5');
        expect(config.normalize('100'), '100');
      });

      test('empty string returns empty', () {
        const config = LocaleNumberConfig.dotDecimal;
        expect(config.normalize(''), '');
      });

      test('integer without separators is unchanged', () {
        const config = LocaleNumberConfig.dotDecimal;
        expect(config.normalize('12345'), '12345');

        const configId = LocaleNumberConfig.commaDecimal;
        expect(configId.normalize('12345'), '12345');
      });

      test('hand-rolled config with grouping == decimal does not strip the decimal', () {
        // Defensive: if anyone constructs a config where grouping equals decimal
        // (no real locale does this), normalize must not eat the decimal mark.
        const config = LocaleNumberConfig(decimalSeparator: ',', groupingSeparator: ',', locale: 'broken');
        expect(config.normalize('1,5'), '1.5');
      });
    });

    group('parseDecimal', () {
      test('US locale: parses thousands-grouped fiat input', () {
        const config = LocaleNumberConfig.dotDecimal;
        expect(config.parseDecimal('1,000'), Decimal.parse('1000'));
        expect(config.parseDecimal('1,000.50'), Decimal.parse('1000.50'));
        expect(config.parseDecimal('0.5'), Decimal.parse('0.5'));
      });

      test('Indonesian locale: parses thousands-grouped fiat input', () {
        const config = LocaleNumberConfig.commaDecimal;
        expect(config.parseDecimal('1.000'), Decimal.parse('1000'));
        expect(config.parseDecimal('1.000,50'), Decimal.parse('1000.50'));
        expect(config.parseDecimal('0,5'), Decimal.parse('0.5'));
      });

      test('throws InvalidNumberInputException on garbage input', () {
        const config = LocaleNumberConfig.dotDecimal;
        expect(() => config.parseDecimal('abc'), throwsA(isA<InvalidNumberInputException>()));
        expect(() => config.parseDecimal('1.2.3'), throwsA(isA<InvalidNumberInputException>()));
        expect(() => config.parseDecimal('.'), throwsA(isA<InvalidNumberInputException>()));
        expect(() => config.parseDecimal(''), throwsA(isA<InvalidNumberInputException>()));
      });

      test('US locale: tolerates trailing decimal separator (mid-typing)', () {
        const config = LocaleNumberConfig.dotDecimal;
        expect(config.parseDecimal('1.'), Decimal.one);
        expect(config.parseDecimal('100.'), Decimal.parse('100'));
        expect(config.parseDecimal('1,000.'), Decimal.parse('1000'));
      });

      test('Indonesian locale: tolerates trailing decimal separator (mid-typing)', () {
        const config = LocaleNumberConfig.commaDecimal;
        expect(config.parseDecimal('1,'), Decimal.one);
        expect(config.parseDecimal('100,'), Decimal.parse('100'));
        expect(config.parseDecimal('1.000,'), Decimal.parse('1000'));
      });

      test('still throws on multiple decimal marks even with trailing separator', () {
        const config = LocaleNumberConfig.dotDecimal;
        expect(() => config.parseDecimal('1.2.'), throwsA(isA<InvalidNumberInputException>()));
      });

      test('exception carries raw and normalized strings', () {
        const config = LocaleNumberConfig.commaDecimal;
        try {
          config.parseDecimal('1.2.3,nope');
          fail('expected InvalidNumberInputException');
        } on InvalidNumberInputException catch (e) {
          expect(e.rawInput, '1.2.3,nope');
          expect(e.normalized, '123.nope');
        }
      });
    });

    group('localize', () {
      test('US locale: formats with dot decimal and comma grouping', () {
        const config = LocaleNumberConfig.dotDecimal;
        expect(config.localize('1000.50'), '1,000.50');
        expect(config.localize('1000000.99'), '1,000,000.99');
        expect(config.localize('0.5'), '0.5');
        expect(config.localize('100'), '100');
      });

      test('Indonesian locale: formats with comma decimal and dot grouping', () {
        const config = LocaleNumberConfig.commaDecimal;
        expect(config.localize('1000.50'), '1.000,50');
        expect(config.localize('1000000.99'), '1.000.000,99');
        expect(config.localize('0.5'), '0,5');
        expect(config.localize('100'), '100');
      });

      test('without grouping separators', () {
        const config = LocaleNumberConfig.dotDecimal;
        expect(config.localize('1000.50', addGroupingSeparators: false), '1000.50');

        const configId = LocaleNumberConfig.commaDecimal;
        expect(configId.localize('1000.50', addGroupingSeparators: false), '1000,50');
      });
    });

    group('roundtrip: normalize then localize', () {
      test('US locale roundtrip', () {
        const config = LocaleNumberConfig.dotDecimal;
        final localized = '1,000.50';
        final normalized = config.normalize(localized);
        expect(normalized, '1000.50');
        expect(config.localize(normalized), localized);
      });

      test('Indonesian locale roundtrip', () {
        const config = LocaleNumberConfig.commaDecimal;
        final localized = '1.000,50';
        final normalized = config.normalize(localized);
        expect(normalized, '1000.50');
        expect(config.localize(normalized), localized);
      });
    });
  });

  group('DecimalInputFilter (locale-aware)', () {
    /// Simulates typing: one character at a time (newText is 1 char longer).
    TextEditingValue typeChar(DecimalInputFilter filter, String currentText, String charToType) {
      final oldValue = TextEditingValue(
        text: currentText,
        selection: TextSelection.collapsed(offset: currentText.length),
      );
      final newText = currentText + charToType;
      final newValue = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      return filter.formatEditUpdate(oldValue, newValue);
    }

    /// Simulates pasting: multiple characters change at once.
    TextEditingValue paste(DecimalInputFilter filter, String currentText, String pastedText) {
      final oldValue = TextEditingValue(
        text: currentText,
        selection: TextSelection.collapsed(offset: currentText.length),
      );
      final newValue = TextEditingValue(
        text: pastedText,
        selection: TextSelection.collapsed(offset: pastedText.length),
      );
      return filter.formatEditUpdate(oldValue, newValue);
    }

    group('US locale (dot decimal) - typing', () {
      late DecimalInputFilter filter;

      setUp(() {
        filter = DecimalInputFilter(localeConfig: LocaleNumberConfig.dotDecimal);
      });

      test('allows empty input', () {
        final result = filter.formatEditUpdate(
          const TextEditingValue(text: '1', selection: TextSelection.collapsed(offset: 1)),
          const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0)),
        );
        expect(result.text, '');
      });

      test('allows integer input', () {
        final result = typeChar(filter, '12', '3');
        expect(result.text, '123');
      });

      test('allows dot as decimal separator', () {
        final result = typeChar(filter, '1', '.');
        expect(result.text, '1.');
      });

      test('also accepts comma as decimal (converts to dot for US)', () {
        final result = typeChar(filter, '1', ',');
        expect(result.text, '1.');
      });

      test('lone dot becomes 0.', () {
        final result = typeChar(filter, '', '.');
        expect(result.text, '0.');
      });

      test('lone comma also becomes 0. (converted to locale decimal)', () {
        final result = typeChar(filter, '', ',');
        expect(result.text, '0.');
      });

      test('rejects second decimal separator', () {
        final result = typeChar(filter, '1.2', '.');
        expect(result.text, '1.2');
      });

      test('rejects leading zeros', () {
        final result = typeChar(filter, '0', '1');
        expect(result.text, '0');
      });

      test('allows 0 followed by decimal', () {
        final result = typeChar(filter, '0', '.');
        expect(result.text, '0.');
      });

      test('respects maxDecimalPlaces', () {
        final filter2dp = DecimalInputFilter(localeConfig: LocaleNumberConfig.dotDecimal, maxDecimalPlaces: 2);
        expect(typeChar(filter2dp, '1.2', '3').text, '1.23');
        expect(typeChar(filter2dp, '1.23', '4').text, '1.23');
      });

      test('blocks decimal when maxDecimalPlaces is 0', () {
        final filter0dp = DecimalInputFilter(localeConfig: LocaleNumberConfig.dotDecimal, maxDecimalPlaces: 0);
        expect(typeChar(filter0dp, '1', '.').text, '1');
        expect(typeChar(filter0dp, '', '.').text, '');
        expect(typeChar(filter0dp, '12', '3').text, '123');
      });
    });

    group('Indonesian locale (comma decimal) - typing', () {
      late DecimalInputFilter filter;

      setUp(() {
        filter = DecimalInputFilter(localeConfig: LocaleNumberConfig.commaDecimal);
      });

      test('allows comma as decimal separator', () {
        final result = typeChar(filter, '1', ',');
        expect(result.text, '1,');
      });

      test('also accepts dot as decimal (converts to comma for Indonesian)', () {
        final result = typeChar(filter, '1', '.');
        expect(result.text, '1,');
      });

      test('lone comma becomes 0,', () {
        final result = typeChar(filter, '', ',');
        expect(result.text, '0,');
      });

      test('lone dot also becomes 0, (converted to locale decimal)', () {
        final result = typeChar(filter, '', '.');
        expect(result.text, '0,');
      });

      test('typing digits after comma works', () {
        var result = typeChar(filter, '1,', '5');
        expect(result.text, '1,5');
      });

      test('rejects second decimal separator', () {
        final result = typeChar(filter, '1,2', ',');
        expect(result.text, '1,2');
      });

      test('rejects dot when comma already present (already has decimal)', () {
        final result = typeChar(filter, '1,2', '.');
        expect(result.text, '1,2');
      });

      test('respects maxDecimalPlaces', () {
        final filter2dp = DecimalInputFilter(localeConfig: LocaleNumberConfig.commaDecimal, maxDecimalPlaces: 2);
        expect(typeChar(filter2dp, '1,2', '3').text, '1,23');
        expect(typeChar(filter2dp, '1,23', '4').text, '1,23');
      });

      test('blocks decimal when maxDecimalPlaces is 0 (IDR)', () {
        final filter0dp = DecimalInputFilter(localeConfig: LocaleNumberConfig.commaDecimal, maxDecimalPlaces: 0);
        expect(typeChar(filter0dp, '1', ',').text, '1');
        expect(typeChar(filter0dp, '1', '.').text, '1');
        expect(typeChar(filter0dp, '', ',').text, '');
        expect(typeChar(filter0dp, '12', '3').text, '123');
      });
    });

    group('US locale - paste', () {
      late DecimalInputFilter filter;

      setUp(() {
        filter = DecimalInputFilter(localeConfig: LocaleNumberConfig.dotDecimal);
      });

      test('strips comma thousands on paste', () {
        final result = paste(filter, '', '1,000');
        expect(result.text, '1000');
      });

      test('keeps dot decimal and strips comma thousands', () {
        final result = paste(filter, '', '1,000.50');
        expect(result.text, '1000.50');
      });

      test('handles large pasted number', () {
        final result = paste(filter, '', '1,234,567.89');
        expect(result.text, '1234567.89');
      });

      test('plain number paste works', () {
        final result = paste(filter, '', '12345');
        expect(result.text, '12345');
      });
    });

    group('Indonesian locale - paste', () {
      late DecimalInputFilter filter;

      setUp(() {
        filter = DecimalInputFilter(localeConfig: LocaleNumberConfig.commaDecimal);
      });

      test('strips dot thousands on paste (1.000 → 1000)', () {
        final result = paste(filter, '', '1.000');
        expect(result.text, '1000');
      });

      test('handles full Indonesian format paste (1.000,50)', () {
        final result = paste(filter, '', '1.000,50');
        expect(result.text, '1000,50');
      });

      test('strips dot thousands from large number', () {
        final result = paste(filter, '', '10.000.000');
        expect(result.text, '10000000');
      });

      test('plain number paste works', () {
        final result = paste(filter, '', '12345');
        expect(result.text, '12345');
      });

      test('paste with only comma decimal', () {
        final result = paste(filter, '', '100,5');
        expect(result.text, '100,5');
      });
    });

    group('cross-locale scenarios', () {
      test('Indonesian user types dot on keyboard → converted to comma (decimal)', () {
        final idFilter = DecimalInputFilter(localeConfig: LocaleNumberConfig.commaDecimal);
        final result = typeChar(idFilter, '100', '.');
        expect(result.text, '100,');
      });

      test('US user types comma on keyboard → converted to dot (decimal)', () {
        final usFilter = DecimalInputFilter(localeConfig: LocaleNumberConfig.dotDecimal);
        final result = typeChar(usFilter, '100', ',');
        expect(result.text, '100.');
      });

      test('Indonesian user pastes US-formatted 1.500 → dot stripped as thousands → 1500', () {
        final idFilter = DecimalInputFilter(localeConfig: LocaleNumberConfig.commaDecimal);
        final result = paste(idFilter, '', '1.500');
        expect(result.text, '1500');
      });

      test('US user pastes 1.000 → kept as 1.000 (decimal)', () {
        // In US locale during paste: comma is grouping and stripped.
        // Dot is decimal and kept. "1.000" = one with 3 decimal places.
        final usFilter = DecimalInputFilter(localeConfig: LocaleNumberConfig.dotDecimal);
        final result = paste(usFilter, '', '1.000');
        expect(result.text, '1.000');
      });

      test('Indonesian user pastes 1,500 from US → comma is decimal → 1,500 (one and a half)', () {
        final idFilter = DecimalInputFilter(localeConfig: LocaleNumberConfig.commaDecimal);
        final result = paste(idFilter, '', '1,500');
        expect(result.text, '1,500');
      });
    });
  });

  group('NumberFormattingService (locale-aware)', () {
    final usService = NumberFormattingService(localeConfig: LocaleNumberConfig.dotDecimal);
    final idService = NumberFormattingService(localeConfig: LocaleNumberConfig.commaDecimal);
    final scaleFactor = BigInt.from(10).pow(NumberFormattingService.decimals);

    group('formatBalance with locale', () {
      test('US locale: formats with dot decimal and comma thousands', () {
        final balance = BigInt.parse('1234500000000000'); // 1234.5
        expect(usService.formatBalance(balance, smartDecimals: 2), '1,234.5');
      });

      test('Indonesian locale: formats with comma decimal and dot thousands', () {
        final balance = BigInt.parse('1234500000000000'); // 1234.5
        expect(idService.formatBalance(balance, smartDecimals: 2), '1.234,5');
      });

      test('US locale: no thousands separators', () {
        final balance = BigInt.parse('1234500000000000');
        expect(usService.formatBalance(balance, smartDecimals: 4, addThousandsSeparators: false), '1234.5');
      });

      test('Indonesian locale: no thousands separators', () {
        final balance = BigInt.parse('1234500000000000');
        expect(idService.formatBalance(balance, smartDecimals: 4, addThousandsSeparators: false), '1234,5');
      });

      test('zero balance is always 0', () {
        expect(idService.formatBalance(BigInt.zero), '0');
      });

      test('Indonesian locale: large balance', () {
        final balance = BigInt.parse('1234567890123000000000'); // 1,234,567,890.123
        expect(idService.formatBalance(balance, smartDecimals: 3), '1.234.567.890,123');
      });
    });

    group('parseAmount with locale', () {
      test('US locale: parses dot decimal', () {
        expect(usService.parseAmount('1.5'), scaleFactor * BigInt.from(15) ~/ BigInt.from(10));
      });

      test('US locale: strips comma thousands before parsing', () {
        expect(usService.parseAmount('1,000.5'), BigInt.parse('1000500000000000'));
      });

      test('Indonesian locale: parses comma decimal', () {
        expect(idService.parseAmount('1,5'), scaleFactor * BigInt.from(15) ~/ BigInt.from(10));
      });

      test('Indonesian locale: strips dot thousands before parsing', () {
        expect(idService.parseAmount('1.000,5'), BigInt.parse('1000500000000000'));
      });

      test('Indonesian locale: 1.000 means 1000 (not 1.000)', () {
        expect(idService.parseAmount('1.000'), scaleFactor * BigInt.from(1000));
      });

      test('US locale: 1.000 means 1.000 (one with three decimal places)', () {
        expect(usService.parseAmount('1.000'), scaleFactor * BigInt.one);
      });

      test('empty string returns zero', () {
        expect(idService.parseAmount(''), BigInt.zero);
      });

      test('invalid string returns null', () {
        expect(usService.parseAmount('abc'), isNull);
      });

      test('Indonesian locale: integer without separators', () {
        expect(idService.parseAmount('1500'), scaleFactor * BigInt.from(1500));
      });
    });

    group('parseAmount + formatBalance roundtrip', () {
      test('US locale roundtrip', () {
        final parsed = usService.parseAmount('1,234.56');
        expect(parsed, isNotNull);
        final formatted = usService.formatBalance(parsed!, smartDecimals: 2);
        expect(formatted, '1,234.56');
      });

      test('Indonesian locale roundtrip', () {
        final parsed = idService.parseAmount('1.234,56');
        expect(parsed, isNotNull);
        final formatted = idService.formatBalance(parsed!, smartDecimals: 2);
        expect(formatted, '1.234,56');
      });
    });
  });

  group('Real-world scenarios', () {
    final usService = NumberFormattingService(localeConfig: LocaleNumberConfig.dotDecimal);
    final idService = NumberFormattingService(localeConfig: LocaleNumberConfig.commaDecimal);
    final scaleFactor = BigInt.from(10).pow(NumberFormattingService.decimals);

    test('Indonesian user inputs 1.000 intending Rp 1000 (not 1.000 QUAN)', () {
      final parsed = idService.parseAmount('1.000');
      expect(parsed, scaleFactor * BigInt.from(1000));
    });

    test('US user inputs 1.000 intending 1 QUAN with trailing zeros', () {
      final parsed = usService.parseAmount('1.000');
      expect(parsed, scaleFactor * BigInt.one);
    });

    test('Indonesian user inputs 0,5 intending half a unit', () {
      final parsed = idService.parseAmount('0,5');
      expect(parsed, scaleFactor ~/ BigInt.two);
    });

    test('US user inputs 0.5 intending half a unit', () {
      final parsed = usService.parseAmount('0.5');
      expect(parsed, scaleFactor ~/ BigInt.two);
    });

    test('Indonesian user copies 10.500,75 from a local source', () {
      final parsed = idService.parseAmount('10.500,75');
      final expected = (scaleFactor * BigInt.from(1050075)) ~/ BigInt.from(100);
      expect(parsed, expected);
    });

    test('US user copies 10,500.75 from a local source', () {
      final parsed = usService.parseAmount('10,500.75');
      final expected = (scaleFactor * BigInt.from(1050075)) ~/ BigInt.from(100);
      expect(parsed, expected);
    });

    test('Indonesian user types dot on iOS keyboard → gets comma in text field', () {
      final filter = DecimalInputFilter(localeConfig: LocaleNumberConfig.commaDecimal);
      // Simulates typing "1" then "." on keyboard
      final result = filter.formatEditUpdate(
        const TextEditingValue(text: '1', selection: TextSelection.collapsed(offset: 1)),
        const TextEditingValue(text: '1.', selection: TextSelection.collapsed(offset: 2)),
      );
      // Should convert to comma (locale's decimal separator)
      expect(result.text, '1,');
    });

    test('US user types comma on some keyboards → gets dot in text field', () {
      final filter = DecimalInputFilter(localeConfig: LocaleNumberConfig.dotDecimal);
      final result = filter.formatEditUpdate(
        const TextEditingValue(text: '1', selection: TextSelection.collapsed(offset: 1)),
        const TextEditingValue(text: '1,', selection: TextSelection.collapsed(offset: 2)),
      );
      expect(result.text, '1.');
    });

    test('DecimalInputFilter blocks IDR decimal input (0 decimal places)', () {
      final filter = DecimalInputFilter(localeConfig: LocaleNumberConfig.commaDecimal, maxDecimalPlaces: 0);
      final oldValue = const TextEditingValue(text: '1000', selection: TextSelection.collapsed(offset: 4));
      // Try comma
      var newValue = const TextEditingValue(text: '1000,', selection: TextSelection.collapsed(offset: 5));
      expect(filter.formatEditUpdate(oldValue, newValue).text, '1000');
      // Try dot
      newValue = const TextEditingValue(text: '1000.', selection: TextSelection.collapsed(offset: 5));
      expect(filter.formatEditUpdate(oldValue, newValue).text, '1000');
    });

    test('DecimalInputFilter blocks JPY decimal input (0 decimal places, dot locale)', () {
      final filter = DecimalInputFilter(localeConfig: LocaleNumberConfig.dotDecimal, maxDecimalPlaces: 0);
      final oldValue = const TextEditingValue(text: '1000', selection: TextSelection.collapsed(offset: 4));
      var newValue = const TextEditingValue(text: '1000.', selection: TextSelection.collapsed(offset: 5));
      expect(filter.formatEditUpdate(oldValue, newValue).text, '1000');
      newValue = const TextEditingValue(text: '1000,', selection: TextSelection.collapsed(offset: 5));
      expect(filter.formatEditUpdate(oldValue, newValue).text, '1000');
    });

    test('USD allows 2 decimal places', () {
      final filter = DecimalInputFilter(localeConfig: LocaleNumberConfig.dotDecimal, maxDecimalPlaces: 2);
      final result = filter.formatEditUpdate(
        const TextEditingValue(text: '10.9', selection: TextSelection.collapsed(offset: 4)),
        const TextEditingValue(text: '10.99', selection: TextSelection.collapsed(offset: 5)),
      );
      expect(result.text, '10.99');

      final result2 = filter.formatEditUpdate(
        const TextEditingValue(text: '10.99', selection: TextSelection.collapsed(offset: 5)),
        const TextEditingValue(text: '10.999', selection: TextSelection.collapsed(offset: 6)),
      );
      expect(result2.text, '10.99');
    });

    test('EUR with comma decimal allows 2 decimal places', () {
      final filter = DecimalInputFilter(localeConfig: LocaleNumberConfig.commaDecimal, maxDecimalPlaces: 2);
      final result = filter.formatEditUpdate(
        const TextEditingValue(text: '10,9', selection: TextSelection.collapsed(offset: 4)),
        const TextEditingValue(text: '10,99', selection: TextSelection.collapsed(offset: 5)),
      );
      expect(result.text, '10,99');

      final result2 = filter.formatEditUpdate(
        const TextEditingValue(text: '10,99', selection: TextSelection.collapsed(offset: 5)),
        const TextEditingValue(text: '10,999', selection: TextSelection.collapsed(offset: 6)),
      );
      expect(result2.text, '10,99');
    });

    test('Full typing flow: Indonesian user types 1500,75', () {
      final filter = DecimalInputFilter(localeConfig: LocaleNumberConfig.commaDecimal);
      // Type 1
      var result = filter.formatEditUpdate(
        const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0)),
        const TextEditingValue(text: '1', selection: TextSelection.collapsed(offset: 1)),
      );
      expect(result.text, '1');
      // Type 5
      result = filter.formatEditUpdate(
        TextEditingValue(
          text: result.text,
          selection: TextSelection.collapsed(offset: result.text.length),
        ),
        const TextEditingValue(text: '15', selection: TextSelection.collapsed(offset: 2)),
      );
      expect(result.text, '15');
      // Type 0
      result = filter.formatEditUpdate(
        TextEditingValue(
          text: result.text,
          selection: TextSelection.collapsed(offset: result.text.length),
        ),
        const TextEditingValue(text: '150', selection: TextSelection.collapsed(offset: 3)),
      );
      expect(result.text, '150');
      // Type 0
      result = filter.formatEditUpdate(
        TextEditingValue(
          text: result.text,
          selection: TextSelection.collapsed(offset: result.text.length),
        ),
        const TextEditingValue(text: '1500', selection: TextSelection.collapsed(offset: 4)),
      );
      expect(result.text, '1500');
      // Type , (decimal)
      result = filter.formatEditUpdate(
        TextEditingValue(
          text: result.text,
          selection: TextSelection.collapsed(offset: result.text.length),
        ),
        const TextEditingValue(text: '1500,', selection: TextSelection.collapsed(offset: 5)),
      );
      expect(result.text, '1500,');
      // Type 7
      result = filter.formatEditUpdate(
        TextEditingValue(
          text: result.text,
          selection: TextSelection.collapsed(offset: result.text.length),
        ),
        const TextEditingValue(text: '1500,7', selection: TextSelection.collapsed(offset: 6)),
      );
      expect(result.text, '1500,7');
      // Type 5
      result = filter.formatEditUpdate(
        TextEditingValue(
          text: result.text,
          selection: TextSelection.collapsed(offset: result.text.length),
        ),
        const TextEditingValue(text: '1500,75', selection: TextSelection.collapsed(offset: 7)),
      );
      expect(result.text, '1500,75');
    });

    test('Full typing flow: Indonesian user types with dot keyboard (iOS)', () {
      final filter = DecimalInputFilter(localeConfig: LocaleNumberConfig.commaDecimal);
      // Type 1
      var result = filter.formatEditUpdate(
        const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0)),
        const TextEditingValue(text: '1', selection: TextSelection.collapsed(offset: 1)),
      );
      expect(result.text, '1');
      // Type 5
      result = filter.formatEditUpdate(
        TextEditingValue(
          text: result.text,
          selection: TextSelection.collapsed(offset: result.text.length),
        ),
        const TextEditingValue(text: '15', selection: TextSelection.collapsed(offset: 2)),
      );
      expect(result.text, '15');
      // Type . on iOS keyboard (should become ,)
      result = filter.formatEditUpdate(
        TextEditingValue(
          text: result.text,
          selection: TextSelection.collapsed(offset: result.text.length),
        ),
        const TextEditingValue(text: '15.', selection: TextSelection.collapsed(offset: 3)),
      );
      expect(result.text, '15,');
      // Type 5
      result = filter.formatEditUpdate(
        TextEditingValue(
          text: result.text,
          selection: TextSelection.collapsed(offset: result.text.length),
        ),
        const TextEditingValue(text: '15,5', selection: TextSelection.collapsed(offset: 4)),
      );
      expect(result.text, '15,5');
    });
  });
}
