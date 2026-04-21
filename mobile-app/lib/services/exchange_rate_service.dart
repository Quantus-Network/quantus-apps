import 'package:decimal/decimal.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';

/// Provides QUAN → fiat exchange rates.
///
/// All rates are currently fixed at 1:1 against USD (and approximate
/// cross-rates for other currencies). Replace [_rates] with a real API
/// response when live pricing is available.
class ExchangeRateService {
  static final ExchangeRateService _instance = ExchangeRateService._internal();
  factory ExchangeRateService() => _instance;
  ExchangeRateService._internal();

  /// Fixed rates: 1 QUAN in each fiat currency.
  /// When a live price feed is integrated, populate this map from the API.
  static final Map<FiatCurrency, Decimal> _rates = {
    FiatCurrency.usd: Decimal.fromInt(1),
    FiatCurrency.myr: Decimal.parse('3,96'),
    FiatCurrency.idr: Decimal.parse('17138.90'),
    FiatCurrency.jpy: Decimal.parse('158,99'),
    FiatCurrency.eur: Decimal.parse('0,85'),
    FiatCurrency.gbp: Decimal.parse('0,74'),
  };

  /// Returns the current QUAN price in [fiat].
  Decimal getRate(FiatCurrency fiat) {
    final rate = _rates[fiat];
    if (rate == null) throw StateError('No rate for ${fiat.code}');
    return rate;
  }

  /// Converts a [quanAmount] (precise Decimal)
  /// to the given [fiat] currency using the current rate.
  Decimal convert(Decimal quanAmount, FiatCurrency fiat) => quanAmount * getRate(fiat);
}
