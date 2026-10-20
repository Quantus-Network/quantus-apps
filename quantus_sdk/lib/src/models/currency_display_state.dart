import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:quantus_sdk/src/models/fiat_currency.dart';
import 'package:quantus_sdk/src/services/exchange_rate_service.dart';
import 'package:quantus_sdk/src/services/locale_number_config.dart';
import 'package:quantus_sdk/src/services/number_formatting_service.dart';

/// A token amount resolved for display: the formatted token amount and, when a
/// token price is known, the same amount in the selected fiat currency.
class CurrencyDisplayState {
  final String primaryAmount;
  final String? secondaryAmount;
  final FiatCurrency selectedFiat;

  const CurrencyDisplayState({required this.primaryAmount, this.secondaryAmount, required this.selectedFiat});

  /// [fiatRate] adds the fiat amount; it stays out while no token price is known.
  factory CurrencyDisplayState.format(
    BigInt amount, {
    required FiatCurrency selectedFiat,
    required NumberFormattingService formatter,
    required LocaleNumberConfig localeConfig,
    required int tokenDecimals,
    required bool withTokenSymbol,
    ExchangeRateService? fiatRate,
  }) {
    final tokenFormatted = formatter.formatBalance(amount, smartDecimals: tokenDecimals, addSymbol: withTokenSymbol);
    final withFiat = fiatRate != null && fiatRate.hasTokenPrice;
    return CurrencyDisplayState(
      primaryAmount: tokenFormatted,
      secondaryAmount: withFiat ? selectedFiat.format(fiatNumeric(amount, selectedFiat, fiatRate, localeConfig)) : null,
      selectedFiat: selectedFiat,
    );
  }

  /// [rawBalance] in [fiat] with the currency's decimal places and locale separators.
  static String fiatNumeric(
    BigInt rawBalance,
    FiatCurrency fiat,
    ExchangeRateService xRate,
    LocaleNumberConfig localeConfig,
  ) {
    final fiatValue = xRate.tokenToFiat(rawBalance, fiat, AppConstants.decimals);
    return localeConfig.localize(fiatValue.toStringAsFixed(fiat.decimals));
  }

  CurrencyDisplayState copyWith({String? primaryAmount, String? secondaryAmount, FiatCurrency? selectedFiat}) =>
      CurrencyDisplayState(
        primaryAmount: primaryAmount ?? this.primaryAmount,
        secondaryAmount: secondaryAmount ?? this.secondaryAmount,
        selectedFiat: selectedFiat ?? this.selectedFiat,
      );
}
