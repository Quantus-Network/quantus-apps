// Keep for potential future use (grouping)
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart'; // For debugPrint

class NumberFormattingService {
  static const int decimals = AppConstants.decimals;
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

    // 1. Perform division to get the precise decimal value.
    final decimalBalance = (Decimal.fromBigInt(balance) / scaleFactorDecimal).toDecimal(
      scaleOnInfinitePrecision:
          maxDecimals * 3, // Note: We never have an infinite number of decimals because we divide by powers of 10.
    );

    // 2. Convert to a string for manipulation.
    String asString = decimalBalance.toString();

    // 3. Manually truncate the string representation.
    final dotIndex = asString.indexOf('.');
    if (dotIndex != -1) {
      // Check if there are enough characters after the dot.
      if (asString.length > dotIndex + maxDecimals + 1) {
        asString = asString.substring(0, dotIndex + maxDecimals + 1);
      }
    }

    // 4. Remove any trailing zeros from the fractional part for a clean look.
    if (asString.contains('.')) {
      asString = asString.replaceAll(RegExp(r'0+$'), '');
      // If we're left with a trailing dot, remove it.
      if (asString.endsWith('.')) {
        asString = asString.substring(0, asString.length - 1);
      }
    }

    // 5. Manually add thousand separators to the integer part.
    final parts = asString.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

    final formattedInteger = integerPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return formattedInteger + decimalPart;
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
