// Keep for potential future use (grouping)
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:quantus_sdk/quantus_sdk.dart'; // For debugPrint

class NumberFormattingService {
  static const int decimals = AppConstants.decimals;
  static final BigInt scaleFactorBigInt = BigInt.from(10).pow(decimals);
  static final Decimal scaleFactorDecimal = Decimal.fromBigInt(scaleFactorBigInt);

  /// Formats a raw BigInt balance (representing the smallest unit) into a
  /// user-readable string with a specified number of decimal places.
  ///
  /// Example: 1234500000000 -> "1.2345" (with maxDecimals = 4)
  String formatBalance(BigInt balance, {int maxDecimals = 6}) {
    if (balance == BigInt.zero) {
      return '0';
    }

    // Perform division with Decimal
    final decimalBalance = (Decimal.fromBigInt(balance) / scaleFactorDecimal).toDecimal(
      scaleOnInfinitePrecision: maxDecimals,
    );

    // Use a NumberFormat that can handle the full decimal range and grouping.
    // 'en_US' locale is used to ensure '.' is the decimal separator and ',' is for grouping.
    final formatter = NumberFormat.decimalPatternDigits(locale: 'en_US', decimalDigits: maxDecimals);

    String formatted = formatter.format(decimalBalance.toDouble());

    // The formatter might add unnecessary trailing zeros up to `maxDecimals`,
    // and we want to trim them for a cleaner look if they are not significant.
    if (formatted.contains('.')) {
      // Remove trailing zeros, but not if it's the only digit after the decimal point.
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      // If we are left with a trailing decimal point, remove it.
      if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
    }

    return formatted;
  }

  /// Parses a user-entered formatted string amount (e.g., "1.23") into a
  /// raw BigInt amount scaled by the chain's decimals.
  ///
  /// Returns null if the input string is invalid.
  BigInt? parseAmount(String formattedAmount) {
    if (formattedAmount.isEmpty) {
      return BigInt.zero;
    }

    try {
      final decimalAmount = Decimal.parse(formattedAmount);
      // Check if input precision exceeds chain precision
      if (decimalAmount.scale > decimals) {
        // Option 1: Truncate (like toBigInt does)
        // Option 2: Throw an error - let's stick with truncation for now
        debugPrint('Warning: Input amount $formattedAmount exceeds $decimals decimals, will be truncated.');
      }
      final rawDecimalAmount = decimalAmount * scaleFactorDecimal;
      return rawDecimalAmount.toBigInt(); // toBigInt truncates
    } catch (e) {
      // Correct debugPrint usage
      debugPrint('Error parsing amount $formattedAmount: $e');
      return null;
    }
  }
}
