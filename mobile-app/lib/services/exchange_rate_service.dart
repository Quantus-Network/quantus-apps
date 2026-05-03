import 'package:decimal/decimal.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';

/// Provides QUAN → fiat exchange rates.
///
/// Constructed with a live [rates] map (ISO-4217 code → value in that currency
/// per 1 USD). Falls back to [fallbackRates] for any code not present.
///
/// [quanToUsdRate] defaults to `1` (1 QUAN = 1 USD). Wire a dedicated QUAN
/// price feed into this field when one becomes available.
class ExchangeRateService {
  /// Static rates used before any live or cached data is available (e.g. on
  /// fresh install with no network). Values are approximate and intentionally
  /// conservative — they are replaced by real rates as soon as the first
  /// successful fetch completes.
  static final Map<String, Decimal> fallbackRates = {
    'USD': Decimal.parse('1'),
    'MYR': Decimal.parse('3.97'),
    'IDR': Decimal.parse('17337.90'),
    'JPY': Decimal.parse('156.54'),
    'EUR': Decimal.parse('0.85'),
    'GBP': Decimal.parse('0.73'),
  };

  final Map<String, Decimal> _rates;
  final Decimal quanToUsdRate;

  ExchangeRateService({required Map<String, Decimal> rates, Decimal? quanToUsdRate})
    : _rates = rates,
      quanToUsdRate = quanToUsdRate ?? Decimal.one;

  /// Returns the exchange rate for [fiat] (units per 1 USD).
  Decimal getRate(FiatCurrency fiat) {
    final rate = _rates[fiat.code] ?? fallbackRates[fiat.code];
    if (rate == null) throw Exception('Exchange rate not found for ${fiat.code}!');

    return rate;
  }

  /// Converts [quanAmount] to [fiat] using the current rates.
  Decimal convert(Decimal quanAmount, FiatCurrency fiat) => quanAmount * quanToUsdRate * getRate(fiat);

  /// Converts a raw QUAN [BigInt] (scaled by 10^[quanDecimals]) to a fiat [Decimal].
  ///
  /// Centralises the scale-factor arithmetic so both display providers and the
  /// send screen share a single, testable conversion path.
  Decimal quanRawToFiat(BigInt rawQuan, FiatCurrency fiat, int quanDecimals) {
    final scaleFactor = BigInt.from(10).pow(quanDecimals);
    final quanDecimal = (Decimal.fromBigInt(rawQuan) / Decimal.fromBigInt(scaleFactor)).toDecimal();
    return convert(quanDecimal, fiat);
  }

  /// Converts a [fiatAmount] back to raw QUAN [BigInt] scaled by 10^[quanDecimals].
  ///
  /// Uses the inverse of [convert]: fiat / (quanToUsdRate × rate).
  /// Returns [BigInt.zero] when the effective rate is zero.
  BigInt fiatToQuanRaw(Decimal fiatAmount, FiatCurrency fiat, int quanDecimals) {
    final effectiveRate = quanToUsdRate * getRate(fiat);
    if (effectiveRate == Decimal.zero) return BigInt.zero;
    final scaleFactor = Decimal.fromBigInt(BigInt.from(10).pow(quanDecimals));
    final quanDecimal = (fiatAmount / effectiveRate).toDecimal(scaleOnInfinitePrecision: quanDecimals);
    return (quanDecimal * scaleFactor).toBigInt();
  }
}
