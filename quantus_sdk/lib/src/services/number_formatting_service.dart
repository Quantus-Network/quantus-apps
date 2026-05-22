import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class NumberFormattingService {
  static const int decimals = AppConstants.decimals;
  static final BigInt scaleFactorBigInt = BigInt.from(10).pow(decimals);
  static final Decimal scaleFactorDecimal = Decimal.fromBigInt(scaleFactorBigInt);

  final LocaleNumberConfig _localeConfig;

  NumberFormattingService({LocaleNumberConfig? localeConfig})
    : _localeConfig = localeConfig ?? LocaleNumberConfig.fromDefaultLocale();

  /// Formats a raw BigInt balance (representing the smallest unit) into a
  /// user-readable string with a specified number of decimal places.
  ///
  /// Example: 1234500000000 -> "1.2345" (with maxDecimals = 4, US locale)
  /// Example: 1234500000000 -> "1,2345" (with maxDecimals = 4, Indonesian locale)
  String formatBalance(
    BigInt balance, {
    int maxDecimals = 4,
    bool addThousandsSeparators = true,
    bool addSymbol = false,
  }) {
    String resultString = '0';

    if (balance == BigInt.zero) {
      return addSymbol ? '$resultString ${AppConstants.tokenSymbol}' : resultString;
    }

    final decimalBalance = (Decimal.fromBigInt(balance) / scaleFactorDecimal).toDecimal(
      scaleOnInfinitePrecision: maxDecimals * 3,
    );

    String asString = decimalBalance.toString();

    final dotIndex = asString.indexOf('.');
    if (dotIndex != -1) {
      if (asString.length > dotIndex + maxDecimals + 1) {
        asString = asString.substring(0, dotIndex + maxDecimals + 1);
      }
    }

    if (asString.contains('.')) {
      asString = asString.replaceAll(RegExp(r'0+$'), '');
      if (asString.endsWith('.')) {
        asString = asString.substring(0, asString.length - 1);
      }
    }

    resultString = asString;
    resultString = _localeConfig.localize(resultString, addGroupingSeparators: addThousandsSeparators);

    if (addSymbol) {
      resultString = '$resultString ${AppConstants.tokenSymbol}';
    }
    return resultString;
  }

  /// Formats a balance for payment URL wire transport: dot decimal, no grouping.
  ///
  /// Wire amounts are locale-neutral and must be parsed with [parseWireAmount].
  String formatWireAmount(BigInt balance) {
    return NumberFormattingService(
      localeConfig: LocaleNumberConfig.dotDecimal,
    ).formatBalance(balance, maxDecimals: decimals, addThousandsSeparators: false);
  }

  /// Parses a payment URL amount without assuming the payer's locale.
  ///
  /// Supports canonical dot-decimal wire amounts and legacy locale-formatted
  /// amounts from older POS QR codes.
  BigInt? parseWireAmount(String formattedAmount) {
    if (formattedAmount.isEmpty) {
      return BigInt.zero;
    }

    final config = _wireLocaleConfigFor(formattedAmount);
    return NumberFormattingService(localeConfig: config).parseAmount(formattedAmount);
  }

  static LocaleNumberConfig _wireLocaleConfigFor(String input) {
    final hasComma = input.contains(',');
    final hasDot = input.contains('.');

    if (hasComma && hasDot) {
      final lastComma = input.lastIndexOf(',');
      final lastDot = input.lastIndexOf('.');
      return lastComma > lastDot ? LocaleNumberConfig.commaDecimal : LocaleNumberConfig.dotDecimal;
    }
    if (hasComma) {
      return LocaleNumberConfig.commaDecimal;
    }
    return LocaleNumberConfig.dotDecimal;
  }

  /// Parses a user-entered formatted string amount into a raw BigInt amount
  /// scaled by the chain's decimals.
  ///
  /// The input is interpreted using the [LocaleNumberConfig] supplied at
  /// construction (decimal/grouping separators come from the user's locale).
  /// Returns [BigInt.zero] for an empty string and `null` for unparseable input.
  BigInt? parseAmount(String formattedAmount) {
    if (formattedAmount.isEmpty) {
      return BigInt.zero;
    }

    try {
      final decimalAmount = _localeConfig.parseDecimal(formattedAmount);
      if (decimalAmount.scale > decimals) {
        debugPrint('Warning: Input amount $formattedAmount exceeds $decimals decimals, will be truncated.');
      }
      final rawDecimalAmount = decimalAmount * scaleFactorDecimal;
      return rawDecimalAmount.toBigInt();
    } catch (e) {
      debugPrint('Error parsing amount $formattedAmount: $e');
      return null;
    }
  }
}
