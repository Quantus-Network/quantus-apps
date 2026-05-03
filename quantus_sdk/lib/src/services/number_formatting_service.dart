import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class NumberFormattingService {
  static const int decimals = AppConstants.decimals;
  static final BigInt scaleFactorBigInt = BigInt.from(10).pow(decimals);
  static final Decimal scaleFactorDecimal = Decimal.fromBigInt(scaleFactorBigInt);

  final LocaleNumberConfig _localeConfig;

  NumberFormattingService({required LocaleNumberConfig localeConfig}) : _localeConfig = localeConfig;

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
