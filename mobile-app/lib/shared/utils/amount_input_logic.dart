import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/services/exchange_rate_service.dart';

class ToggledInputResult {
  final String text;
  final BigInt amount;

  ToggledInputResult({required this.text, required this.amount});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToggledInputResult && runtimeType == other.runtimeType && text == other.text && amount == other.amount;

  @override
  int get hashCode => text.hashCode ^ amount.hashCode;
}

class AmountInputLogic {
  final ExchangeRateService exchangeRateService;
  final FiatCurrency selectedFiat;
  final LocaleNumberConfig localeConfig;
  final NumberFormattingService formattingService;

  AmountInputLogic({
    required this.exchangeRateService,
    required this.selectedFiat,
    required this.localeConfig,
    required this.formattingService,
  });

  /// Converts a raw QUAN [BigInt] to a fiat input string using the current
  /// exchange rate and selected fiat currency, formatted for the user's locale.
  String quanToFiatString(BigInt quanAmount) {
    if (quanAmount == BigInt.zero) return '';
    final fiatValue = exchangeRateService.quanRawToFiat(quanAmount, selectedFiat, AppConstants.decimals);
    final canonical = fiatValue.toStringAsFixed(selectedFiat.decimals);
    return localeConfig.localize(canonical, addGroupingSeparators: false);
  }

  /// Parses a locale-formatted fiat input string and returns the equivalent
  /// raw QUAN [BigInt] scaled by [AppConstants.decimals].
  ///
  /// Throws [InvalidNumberInputException] when [fiatText] cannot be parsed.
  BigInt fiatStringToQuan(String fiatText) {
    if (fiatText.isEmpty) return BigInt.zero;
    final fiatDecimal = localeConfig.parseDecimal(fiatText);
    return exchangeRateService.fiatToQuanRaw(fiatDecimal, selectedFiat, AppConstants.decimals);
  }

  /// Parses a QUAN amount string.
  BigInt parseQuanAmount(String text) {
    if (text.isEmpty) return BigInt.zero;
    return formattingService.parseAmount(text) ?? BigInt.zero;
  }

  /// Formats a QUAN amount for display in an input field.
  String formatQuanAmount(BigInt amount) {
    if (amount == BigInt.zero) return '';
    return formattingService.formatBalance(amount, smartDecimals: AppConstants.decimals, addThousandsSeparators: false);
  }

  /// Returns the new input string and amount when toggling between QUAN and Fiat.
  ToggledInputResult getToggledInput({required bool wasFlipped, required BigInt currentAmount}) {
    if (wasFlipped) {
      // Fiat -> QUAN: The user was looking at a fiat amount.
      // We already have currentAmount which was calculated from that fiat amount.
      final text = formatQuanAmount(currentAmount);
      return ToggledInputResult(text: text, amount: currentAmount);
    } else {
      // QUAN -> Fiat: re-parse amount from the rounded fiat string so
      // the displayed value and amount stay in sync.
      final text = quanToFiatString(currentAmount);
      final newAmount = currentAmount == BigInt.zero ? BigInt.zero : fiatStringToQuan(text);
      return ToggledInputResult(text: text, amount: newAmount);
    }
  }

  /// Handles amount change and returns the updated BigInt amount.
  BigInt onAmountChanged({required String value, required bool isFlipped}) {
    if (isFlipped) {
      return fiatStringToQuan(value);
    } else {
      return parseQuanAmount(value);
    }
  }
}
