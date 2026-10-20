import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:quantus_sdk/src/services/exchange_rate_service.dart';
import 'package:quantus_sdk/src/services/quersi_service.dart';
import 'package:quantus_sdk/src/services/settings_service.dart';
import 'package:quantus_sdk/src/utils/print.dart';

/// Persists USD-based exchange rates with the expiry the upstream provider
/// announces, so the cache is busted when new rates are published rather than
/// after an arbitrary local TTL.
class ExchangeRatesStore {
  static const cacheKey = 'exchange_rates_cache';

  /// Guards against an upstream returning a stale or zero expiry, which would
  /// make every cold start hit the network.
  static const minCacheTtlSeconds = 60;

  final SettingsService _settings;

  ExchangeRatesStore(this._settings);

  static Map<String, Decimal> _parse(Map<String, dynamic> ratesJson) =>
      ratesJson.map((k, v) => MapEntry(k, Decimal.parse(v as String)));

  /// Cached rates while they have not expired, else null.
  Map<String, Decimal>? readFresh() {
    final raw = _settings.getString(cacheKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final expiryUnix = decoded['expiry'] as int;
      final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (nowUnix >= expiryUnix) return null;
      return _parse(decoded['rates'] as Map<String, dynamic>);
    } catch (e) {
      quantusPrint('Failed parsing exchange rates: $e');
      return null;
    }
  }

  /// Cached rates regardless of age, or the static fallback rates.
  Map<String, Decimal> readAnyAge() {
    final raw = _settings.getString(cacheKey);
    if (raw == null) return ExchangeRateService.fallbackRates;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return _parse(decoded['rates'] as Map<String, dynamic>);
    } catch (e) {
      quantusPrint('Failed parsing exchange rates cache: $e');
      return ExchangeRateService.fallbackRates;
    }
  }

  Future<void> write(Map<String, Decimal> rates, int timeNextUpdateUnix) async {
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (timeNextUpdateUnix <= nowUnix + minCacheTtlSeconds) {
      quantusPrint('Skipping exchange rates cache write: expiry $timeNextUpdateUnix is too close to now $nowUnix');
      return;
    }
    final payload = {'expiry': timeNextUpdateUnix, 'rates': rates.map((k, v) => MapEntry(k, v.toString()))};
    await _settings.setString(cacheKey, jsonEncode(payload));
  }

  /// Fresh cache, else a fetch that is persisted, else the stale cache or the
  /// static fallback.
  Future<Map<String, Decimal>> load(QuersiService quersi) async {
    final cached = readFresh();
    if (cached != null) return cached;
    try {
      final result = await quersi.getExchangeRates();
      final rates = result.rates.map((k, v) => MapEntry(k, Decimal.parse(v.toString())));
      await write(rates, result.timeNextUpdateUnix);
      return rates;
    } catch (e) {
      quantusPrint('Failed fetching exchange rates: $e');
      return readAnyAge();
    }
  }
}
