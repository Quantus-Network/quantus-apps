// Keep for potential future use (grouping)
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class NumberFormattingService {
  static const int decimals = 12;
  static final BigInt scaleFactorBigInt = BigInt.from(10).pow(decimals);
  static final Decimal scaleFactorDecimal = Decimal.fromBigInt(scaleFactorBigInt);

  /// Formats a raw BigInt balance (representing the smallest unit) into a
  /// user-readable string with a specified number of decimal places.
  ///
  /// Example: 1234500000000 -> "1.2345" (with maxDecimals = 4)
  String formatBalance(BigInt balance, {int maxDecimals = 4}) {
    if (balance == BigInt.zero) {
      return '0';
    }

    // Perform division with Decimal
    final rationalBalance = Decimal.fromBigInt(balance) / scaleFactorDecimal;

    // Convert Rational to Decimal *without* premature scaling
    final decimalBalance = rationalBalance.toDecimal();

    // Now use toStringAsFixed on the resulting Decimal
    String formatted = decimalBalance.toStringAsFixed(maxDecimals);

    // Simple manual trim of trailing zeros and decimal point if necessary
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), ''); // Remove trailing zeros
      if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1); // Remove trailing decimal point
      }
    }

    // Optional: Add grouping separators for the integer part if needed in the future
    // using NumberFormat on the integer part before combining.

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
