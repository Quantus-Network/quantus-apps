import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart'; // Using decimal package for precision

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

    // Use Decimal for precise division
    final decimalBalance = Decimal.fromBigInt(balance) / scaleFactorDecimal;

    // Format using NumberFormat
    // Adjust pattern based on maxDecimals to avoid trailing zeros unless necessary
    final formatter = NumberFormat(
      '#,##0.${'#' * maxDecimals}', // Use '#' for optional decimals
      'en_US',
    );

    // Ensure at least one '0' if result is < 1 (e.g., 0.5)
    String formatted = formatter.format(decimalBalance.toDouble());

    // Remove trailing unnecessary decimal points/zeros if maxDecimals > 0
     if (formatted.contains('.') && maxDecimals > 0) {
       formatted = formatted.replaceAll(RegExp(r'0+$'), ''); // Remove trailing zeros
       if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1); // Remove trailing decimal point
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
      // Use Decimal for precision
      final decimalAmount = Decimal.parse(formattedAmount);
      // Scale up
      final rawDecimalAmount = decimalAmount * scaleFactorDecimal;
      // Convert to BigInt (truncates any sub-unit dust)
      return rawDecimalAmount.toBigInt();
    } catch (e) {
      // Handle parsing errors (invalid format)
      print('Error parsing amount '$formattedAmount': $e');
      return null;
    }
  }
}
