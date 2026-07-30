import 'package:decimal/decimal.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';

/// Provides token → fiat exchange rates.
///
/// Constructed with a live [rates] map (ISO-4217 code → value in that currency
/// per 1 USD). Falls back to [fallbackRates] for any code not present.
///
/// [tokenToUsdRate] defaults to `1` (1 token = 1 USD). Wire a dedicated tokens
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
  final Decimal tokenToUsdRate;

  ExchangeRateService({required Map<String, Decimal> rates, Decimal? tokenToUsdRate})
    : _rates = rates,
      tokenToUsdRate = tokenToUsdRate ?? Decimal.one;

  /// Returns the exchange rate for [fiat] (units per 1 USD).
  Decimal getRate(FiatCurrency fiat) {
    final rate = _rates[fiat.code] ?? fallbackRates[fiat.code];
    if (rate == null) throw Exception('Exchange rate not found for ${fiat.code}!');

    return rate;
  }

  /// Converts [tokenAmount] to [fiat] using the current rates.
  Decimal convert(Decimal tokenAmount, FiatCurrency fiat) {
    final result = (tokenAmount * tokenToUsdRate * getRate(fiat));
    // Round to fiat precision to ensure stable round-trips
    return Decimal.parse(result.toStringAsFixed(fiat.decimals));
  }

  /// Converts a raw tokens [BigInt] (scaled by 10^[tokenDecimals]) to a fiat [Decimal].
  ///
  /// Centralises the scale-factor arithmetic so both display providers and the
  /// send screen share a single, testable conversion path.
  Decimal tokenRawToFiat(BigInt rawToken, FiatCurrency fiat, int tokenDecimals) {
    final scaleFactor = BigInt.from(10).pow(tokenDecimals);
    final tokenDecimal = (Decimal.fromBigInt(rawToken) / Decimal.fromBigInt(scaleFactor)).toDecimal();
    return convert(tokenDecimal, fiat);
  }

  /// Converts a [fiatAmount] back to raw tokens [BigInt] scaled by 10^[tokenDecimals].
  ///
  /// Uses the inverse of [convert]: fiat / (tokenToUsdRate × rate).
  /// Returns [BigInt.zero] when the effective rate is zero.
  BigInt fiatToTokenRaw(Decimal fiatAmount, FiatCurrency fiat, int tokenDecimals) {
    final effectiveRate = tokenToUsdRate * getRate(fiat);
    if (effectiveRate == Decimal.zero) return BigInt.zero;
    final scaleFactor = Decimal.fromBigInt(BigInt.from(10).pow(tokenDecimals));
    final tokenDecimal = (fiatAmount / effectiveRate).toDecimal(scaleOnInfinitePrecision: tokenDecimals);
    return (tokenDecimal * scaleFactor).toBigInt();
  }
}
