import 'package:flutter/services.dart';
import 'package:quantus_sdk/src/services/locale_number_config.dart';

/// A locale-aware [TextInputFormatter] that:
/// - Accepts BOTH `.` and `,` as the decimal separator during **typing**
///   (because mobile keyboards may show either regardless of locale).
/// - Applies locale rules (strips grouping separators) during **paste**.
/// - Enforces a maximum number of decimal places (useful for fiat currencies
///   with 0 decimals like IDR/JPY).
/// - Prevents leading zeros (except for `0` followed by the decimal separator).
/// - Normalizes displayed text to use the locale's decimal separator.
class DecimalInputFilter extends TextInputFormatter {
  final LocaleNumberConfig localeConfig;
  final int? maxDecimalPlaces;

  /// Creates a locale-aware decimal input filter.
  ///
  /// [localeConfig] determines which characters are the decimal and grouping
  /// separators. Defaults to [LocaleNumberConfig.dotDecimal] (US format).
  ///
  /// [maxDecimalPlaces] restricts how many digits after the decimal separator
  /// are allowed. Pass `0` to block decimal input entirely (e.g. for IDR/JPY).
  /// Pass `null` for the default maximum of 12 digits.
  DecimalInputFilter({LocaleNumberConfig? localeConfig, this.maxDecimalPlaces})
    : localeConfig = localeConfig ?? LocaleNumberConfig.dotDecimal;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final sep = localeConfig.decimalSeparator;
    final groupSep = localeConfig.groupingSeparator;

    // Detect paste vs typing: paste inserts multiple characters at once.
    final bool isPaste = (newValue.text.length - oldValue.text.length) > 1;

    String text;

    if (isPaste) {
      // PASTE MODE: apply full locale rules.
      // Strip grouping separators and keep the locale's decimal separator.
      text = newValue.text.replaceAll(groupSep, '');
    } else {
      // TYPING MODE: accept EITHER `.` or `,` as a decimal separator attempt.
      // Mobile keyboards may show either symbol regardless of locale.
      text = newValue.text;

      final hasDecimalAlready = oldValue.text.contains(sep);

      if (!hasDecimalAlready && text.contains(groupSep) && !oldValue.text.contains(groupSep)) {
        // No decimal yet → user typed the "other" separator intending decimal.
        text = text.replaceFirst(groupSep, sep);
      } else if (hasDecimalAlready && text.contains(groupSep) && !oldValue.text.contains(groupSep)) {
        // Already has a decimal → reject the newly typed separator entirely.
        return oldValue;
      }
    }

    // Handle lone decimal separator → "0," or "0."
    if (text == sep || text == '.' || text == ',') {
      if (maxDecimalPlaces == 0) return oldValue;
      return TextEditingValue(text: '0$sep', selection: const TextSelection.collapsed(offset: 2));
    }

    // Handle leading decimal separator (e.g., ",5" → "0,5" or ".5" → "0.5")
    if (text.startsWith(sep) || text.startsWith('.') || text.startsWith(',')) {
      if (maxDecimalPlaces == 0) return oldValue;
      // Normalize the leading separator to the locale's decimal separator.
      if (text.startsWith('.') || text.startsWith(',')) {
        text = sep + text.substring(1);
      }
      text = '0$text';
    }

    // Normalize to canonical form (dot decimal) for validation.
    final normalized = localeConfig.normalize(text);

    // Build validation regex based on maxDecimalPlaces.
    final String decimalRegexPart;
    if (maxDecimalPlaces == 0) {
      decimalRegexPart = '';
    } else {
      final maxDp = maxDecimalPlaces ?? 12;
      decimalRegexPart =
          r'(\.\d{0,'
          '$maxDp'
          r'})?';
    }
    final regex = RegExp('^(0|([1-9]\\d*))$decimalRegexPart\$');

    if (regex.hasMatch(normalized)) {
      // Ensure the text uses the locale's decimal separator for display.
      final displayText = _ensureLocaleDecimal(text);

      if (displayText != newValue.text) {
        return TextEditingValue(
          text: displayText,
          selection: TextSelection.collapsed(offset: displayText.length),
        );
      }
      return newValue;
    }

    return oldValue;
  }

  /// Ensures the text uses only the locale's decimal separator.
  /// Converts any `.` or `,` to the locale's decimal separator.
  String _ensureLocaleDecimal(String text) {
    final sep = localeConfig.decimalSeparator;
    final other = sep == '.' ? ',' : '.';
    return text.replaceAll(other, sep);
  }
}
