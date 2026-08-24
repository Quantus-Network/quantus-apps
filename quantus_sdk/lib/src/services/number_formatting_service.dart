import 'package:decimal/decimal.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/utils/print.dart';

class NumberFormattingService {
  static const int decimals = AppConstants.decimals;
  static final BigInt scaleFactorBigInt = BigInt.from(10).pow(decimals);
  static final Decimal scaleFactorDecimal = Decimal.fromBigInt(scaleFactorBigInt);

  final LocaleNumberConfig _localeConfig;

  NumberFormattingService({LocaleNumberConfig? localeConfig})
    : _localeConfig = localeConfig ?? LocaleNumberConfig.fromDefaultLocale();

  /// Formats a raw BigInt balance (representing the smallest unit) into a
  /// user-readable string.
  ///
  /// [smartDecimals] is the preferred number of fractional digits. For sub-unit
  /// amounts whose first [smartDecimals] digits are all zero, precision is
  /// extended to reveal the first significant digits so a tiny non-zero amount
  /// never renders as "0" — but never beyond [maxDecimals], the absolute cap
  /// (which is treated as at least [smartDecimals]).
  ///
  /// Example: 1234500000000 -> "1.2345" (smartDecimals = 4, US locale)
  /// Example: 100000000      -> "0.0001" (smartDecimals = 2, extended)
  /// Standard token-amount display: 4 smart decimals, extending to the
  /// chain's full precision for smaller amounts.
  String formatAmount(BigInt amount) => formatBalance(amount, smartDecimals: 4, maxDecimals: AppConstants.decimals);

  String formatBalance(
    BigInt balance, {
    int smartDecimals = 4,
    int maxDecimals = 6,
    bool addThousandsSeparators = true,
    bool addSymbol = false,
  }) {
    String resultString = '0';

    if (balance == BigInt.zero) {
      return addSymbol ? '$resultString ${AppConstants.tokenSymbol}' : resultString;
    }

    final decimalBalance = (Decimal.fromBigInt(balance) / scaleFactorDecimal).toDecimal(
      scaleOnInfinitePrecision: decimals,
    );

    String asString = decimalBalance.toString();

    final dotIndex = asString.indexOf('.');
    if (dotIndex != -1) {
      final integerPart = asString.substring(0, dotIndex);
      final fraction = asString.substring(dotIndex + 1);
      final effectiveDecimals = _effectiveDecimals(integerPart, fraction, smartDecimals, maxDecimals);
      if (asString.length > dotIndex + effectiveDecimals + 1) {
        asString = asString.substring(0, dotIndex + effectiveDecimals + 1);
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

  /// Resolves how many fractional digits to display: [smartDecimals] normally,
  /// extended toward the first significant digits for tiny sub-unit amounts,
  /// capped at [maxDecimals] (never below [smartDecimals]).
  int _effectiveDecimals(String integerPart, String fraction, int smartDecimals, int maxDecimals) {
    if (smartDecimals < 1 || integerPart != '0') return smartDecimals;
    final shown = fraction.length > smartDecimals ? fraction.substring(0, smartDecimals) : fraction;
    if (shown.contains(RegExp(r'[1-9]'))) return smartDecimals;
    final firstSignificant = fraction.indexOf(RegExp(r'[1-9]'));
    if (firstSignificant == -1) return smartDecimals;
    final cap = maxDecimals < smartDecimals ? smartDecimals : maxDecimals;
    final extended = firstSignificant + smartDecimals;
    return extended > cap ? cap : extended;
  }

  /// Formats a balance for payment URL wire transport: dot decimal, no grouping.
  ///
  /// Wire amounts are locale-neutral and must be parsed with [parseWireAmount].
  String formatWireAmount(BigInt balance) {
    return NumberFormattingService(
      localeConfig: LocaleNumberConfig.dotDecimal,
    ).formatBalance(balance, smartDecimals: decimals, addThousandsSeparators: false);
  }

  /// Wire amount shape: NNN[.NNN], dot as the decimal separator, no grouping,
  /// no exponent — exactly what [formatWireAmount] produces. At most
  /// [AppConstants.maxWholeDigits] whole digits (MAX_SUPPLY bounds every
  /// legitimate amount) and [AppConstants.decimals] fractional digits.
  /// Scientific notation, signs, and separators are rejected — parsing those
  /// into a BigInt can block the UI isolate for minutes.
  static final RegExp wireAmountPattern = RegExp('^\\d{1,${AppConstants.maxWholeDigits}}(\\.\\d{1,$decimals})?\$');

  /// Parses a payment URL amount in our own wire format.
  ///
  /// Deliberately locale-free: the wire format is ours alone, so the gate below
  /// runs before any locale-aware parsing — comma-decimal locales must not be
  /// able to parse it, and exponent notation must never reach [Decimal], where
  /// it could materialise an attacker-sized BigInt. Everything the gate admits
  /// is already canonical, so the scaling itself is [parseAmount]'s.
  BigInt? parseWireAmount(String formattedAmount) {
    if (formattedAmount.isEmpty) {
      return BigInt.zero;
    }
    if (!wireAmountPattern.hasMatch(formattedAmount)) {
      quantusPrint('Invalid wire amount: $formattedAmount');
      return null;
    }
    return NumberFormattingService(localeConfig: LocaleNumberConfig.dotDecimal).parseAmount(formattedAmount);
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
        quantusPrint('Warning: Input amount $formattedAmount exceeds $decimals decimals, will be truncated.');
      }
      final rawDecimalAmount = decimalAmount * scaleFactorDecimal;
      return rawDecimalAmount.toBigInt();
    } catch (e) {
      quantusPrint('Error parsing amount $formattedAmount: $e');
      return null;
    }
  }
}
