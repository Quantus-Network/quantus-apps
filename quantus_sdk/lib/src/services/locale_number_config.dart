import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Thrown by [LocaleNumberConfig.parseDecimal] when the input cannot be parsed
/// as a decimal number after locale normalization. Callers should catch this
/// at the UI boundary and present a user-friendly message.
class InvalidNumberInputException implements Exception {
  final String rawInput;
  final String normalized;

  const InvalidNumberInputException({required this.rawInput, required this.normalized});

  @override
  String toString() => 'InvalidNumberInputException(raw: "$rawInput", normalized: "$normalized")';
}

/// Encapsulates locale-specific number formatting rules (decimal and grouping
/// separators) so that input parsing, validation, and display are consistent
/// with the user's device locale.
class LocaleNumberConfig {
  final String decimalSeparator;
  final String groupingSeparator;
  final String locale;

  const LocaleNumberConfig({required this.decimalSeparator, required this.groupingSeparator, required this.locale});

  /// Standard US/UK config: dot decimal, comma thousands.
  static const dotDecimal = LocaleNumberConfig(decimalSeparator: '.', groupingSeparator: ',', locale: 'en_US');

  /// European/Indonesian config: comma decimal, dot thousands.
  static const commaDecimal = LocaleNumberConfig(decimalSeparator: ',', groupingSeparator: '.', locale: 'id_ID');

  /// Creates a [LocaleNumberConfig] from the device locale string (e.g. 'en_US', 'id_ID').
  factory LocaleNumberConfig.fromLocale(String locale) {
    final format = NumberFormat.decimalPattern(locale);
    final symbols = format.symbols;
    return LocaleNumberConfig(
      decimalSeparator: symbols.DECIMAL_SEP,
      groupingSeparator: symbols.GROUP_SEP,
      locale: locale,
    );
  }

  /// Creates a [LocaleNumberConfig] from the current default locale.
  factory LocaleNumberConfig.fromDefaultLocale() {
    return LocaleNumberConfig.fromLocale(Intl.defaultLocale ?? 'en_US');
  }

  /// Whether this locale uses comma as the decimal separator.
  bool get isCommaDecimal => decimalSeparator == ',';

  /// Normalizes a locale-formatted input string to a canonical format
  /// (dot as decimal separator, no grouping separators) suitable for
  /// [Decimal.parse] or [double.parse].
  ///
  /// Examples (Indonesian locale where `,` = decimal, `.` = thousands):
  ///   '1.000,50' → '1000.50'
  ///   '1000,5'   → '1000.5'
  ///   '1.000'    → '1000'
  ///
  /// Examples (US locale where `.` = decimal, `,` = thousands):
  ///   '1,000.50' → '1000.50'
  ///   '1000.5'   → '1000.5'
  ///   '1,000'    → '1000'
  String normalize(String input) {
    if (input.isEmpty) return input;

    String result = input;

    // Remove grouping separators. Skip when grouping equals decimal — under any
    // sensible locale this never holds, but guarding keeps the helper safe if
    // it's ever fed a hand-rolled config.
    if (groupingSeparator.isNotEmpty && groupingSeparator != decimalSeparator) {
      result = result.replaceAll(groupingSeparator, '');
    }

    if (decimalSeparator != '.') {
      result = result.replaceAll(decimalSeparator, '.');
    }

    return result;
  }

  /// Parses a locale-formatted numeric string into a [Decimal].
  ///
  /// Tolerates a single trailing decimal separator with no fractional digits
  /// (e.g. `"1."` in en_US or `"1,"` in id_ID) so mid-typing keystrokes don't
  /// look like garbage to callers — `"1."` parses as `Decimal.one`. Strings
  /// with more than one decimal mark (e.g. `"1.2."`) still throw.
  ///
  /// Throws [InvalidNumberInputException] when the input cannot be parsed.
  /// Empty input also throws — callers that want to treat empty as zero should
  /// short-circuit before calling.
  Decimal parseDecimal(String input) {
    final normalized = normalize(input);
    final canonical = (normalized.endsWith('.') && '.'.allMatches(normalized).length == 1)
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final result = Decimal.tryParse(canonical);
    if (result == null) {
      throw InvalidNumberInputException(rawInput: input, normalized: normalized);
    }
    return result;
  }

  /// Converts a canonical numeric string (dot decimal, no grouping) to the
  /// locale's display format.
  ///
  /// If [addGroupingSeparators] is true, thousands grouping is applied.
  String localize(String canonicalInput, {bool addGroupingSeparators = true}) {
    if (canonicalInput.isEmpty) return canonicalInput;

    final parts = canonicalInput.split('.');
    String integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : null;

    if (addGroupingSeparators && integerPart.length > 3) {
      integerPart = integerPart.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}$groupingSeparator',
      );
    }

    if (decimalPart != null) {
      return '$integerPart$decimalSeparator$decimalPart';
    }
    return integerPart;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocaleNumberConfig &&
          runtimeType == other.runtimeType &&
          decimalSeparator == other.decimalSeparator &&
          groupingSeparator == other.groupingSeparator;

  @override
  int get hashCode => decimalSeparator.hashCode ^ groupingSeparator.hashCode;

  @override
  String toString() =>
      'LocaleNumberConfig(decimal: "$decimalSeparator", grouping: "$groupingSeparator", locale: "$locale")';
}
