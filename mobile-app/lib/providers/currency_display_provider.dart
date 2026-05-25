import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/exchange_rate_service.dart';

// ---------------------------------------------------------------------------
// Exchange rate caching helpers
// ---------------------------------------------------------------------------

const _kRatesCacheKey = 'exchange_rates_cache';

/// Parses the inner `rates` object from a decoded cache payload into a
/// `Map<String, Decimal>`. Shared by [_readRatesCache] and [_readRatesCacheAnyAge].
Map<String, Decimal> _parseRatesMap(Map<String, dynamic> ratesJson) =>
    ratesJson.map((k, v) => MapEntry(k, Decimal.parse(v as String)));

/// Reads persisted rates from [settings] and returns them only when the cache
/// has not yet expired. Returns `null` on a cache miss, parse error, or expiry.
Map<String, Decimal>? _readRatesCache(SettingsService settings) {
  final raw = settings.getString(_kRatesCacheKey);
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final expiryUnix = decoded['expiry'] as int;
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (nowUnix >= expiryUnix) return null;
    return _parseRatesMap(decoded['rates'] as Map<String, dynamic>);
  } catch (e) {
    debugPrint('Failed parsing exchange rates: $e');
    return null;
  }
}

/// Like [_readRatesCache] but ignores expiry — used as a last-resort fallback
/// while a network fetch is in progress or has failed.
///
/// Returns [ExchangeRateService.fallbackRates] when SharedPreferences has no
/// entry (fresh install) or when the stored data cannot be parsed, so callers
/// always get a usable map and never throw.
Map<String, Decimal> _readRatesCacheAnyAge(SettingsService settings) {
  final raw = settings.getString(_kRatesCacheKey);
  if (raw == null) return ExchangeRateService.fallbackRates;

  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return _parseRatesMap(decoded['rates'] as Map<String, dynamic>);
  } catch (e) {
    debugPrint('Failed parsing exchange rates cache: $e');

    return ExchangeRateService.fallbackRates;
  }
}

/// Minimum acceptable cache window. Guards against an upstream returning a
/// stale or zero `time_next_update_unix`, which would otherwise cause every
/// cold start to re-hit the network.
const _kMinCacheTtlSeconds = 60;

Future<void> _writeRatesCache(SettingsService settings, Map<String, Decimal> rates, int timeNextUpdateUnix) async {
  final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if (timeNextUpdateUnix <= nowUnix + _kMinCacheTtlSeconds) {
    debugPrint(
      'Skipping exchange rates cache write: timeNextUpdateUnix=$timeNextUpdateUnix '
      'is not at least ${_kMinCacheTtlSeconds}s in the future (now=$nowUnix).',
    );
    return;
  }
  final payload = {'expiry': timeNextUpdateUnix, 'rates': rates.map((k, v) => MapEntry(k, v.toString()))};
  await settings.setString(_kRatesCacheKey, jsonEncode(payload));
}

// ---------------------------------------------------------------------------
// Exchange rates provider (async fetch + server-driven cache)
// ---------------------------------------------------------------------------

/// Resolves the live USD-based exchange rates.
///
/// Strategy (in order):
///   1. Return valid (non-expired) cached rates from the previous fetch.
///   2. Fetch fresh rates from the Taskmaster endpoint and persist them.
///      The cache expiry is set to [time_next_update_unix] from the API
///      response, so the cache is busted exactly when the upstream provider
///      publishes new rates rather than after an arbitrary local TTL.
///   3. On fetch error, return the last persisted rates (even if expired).
///   4. Ultimate fallback: [ExchangeRateService.fallbackRates].
final exchangeRatesProvider = FutureProvider<Map<String, Decimal>>((ref) async {
  final settings = ref.read(settingsServiceProvider);

  final cached = _readRatesCache(settings);
  if (cached != null) return cached;

  try {
    final result = await TaskmasterService().getExchangeRates();
    final rates = result.rates.map((k, v) => MapEntry(k, Decimal.parse(v.toString())));
    await _writeRatesCache(settings, rates, result.timeNextUpdateUnix);

    return rates;
  } catch (e) {
    debugPrint('Failed fetching exchange rates: $e');

    return _readRatesCacheAnyAge(settings);
  }
});

// ---------------------------------------------------------------------------
// Exchange rate service provider
// ---------------------------------------------------------------------------

/// Returns an [ExchangeRateService] backed by the best available rates.
///
/// • While [exchangeRatesProvider] is loading, uses the last persisted rates
///   (any age) so the UI always shows something meaningful.
/// • Once live rates arrive, rebuilds with the fresh data.
final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  final ratesAsync = ref.watch(exchangeRatesProvider);
  final settings = ref.read(settingsServiceProvider);

  return ratesAsync.when(
    data: (rates) => ExchangeRateService(rates: rates),
    loading: () => ExchangeRateService(rates: _readRatesCacheAnyAge(settings)),
    error: (_, _) => ExchangeRateService(rates: _readRatesCacheAnyAge(settings)),
  );
});

// ---------------------------------------------------------------------------
// Selected fiat currency provider
// ---------------------------------------------------------------------------

/// Persists and exposes the user's chosen fiat currency for conversions.
/// Defaults to [FiatCurrency.usd] when no preference has been saved.
///
/// To change the active fiat currency (e.g. from a settings screen):
///   ref.read(selectedFiatCurrencyProvider.notifier).select(FiatCurrency.idr);
final selectedFiatCurrencyProvider = StateNotifierProvider<SelectedFiatCurrencyNotifier, FiatCurrency>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  return SelectedFiatCurrencyNotifier(settings);
});

class SelectedFiatCurrencyNotifier extends StateNotifier<FiatCurrency> {
  final SettingsService _settings;

  static final FiatCurrency _defaultCurrency = FiatCurrency.usd;

  SelectedFiatCurrencyNotifier(this._settings) : super(_load(_settings));

  /// Persists and applies [currency] as the active fiat currency.
  Future<void> select(FiatCurrency currency) async {
    await _settings.setSelectedFiatCurrency(currency.code);
    state = currency;
  }

  Future<void> reset() async {
    await _settings.clearSelectedFiatCurrency();
    state = _defaultCurrency;
  }

  static FiatCurrency _load(SettingsService settings) {
    final code = settings.getSelectedFiatCurrency();
    if (code == null) return _defaultCurrency;
    return FiatCurrency.fromCode(code);
  }
}

// ---------------------------------------------------------------------------
// Currency flip provider
// ---------------------------------------------------------------------------

/// Whether fiat is shown as the primary (large) display and QUAN secondary.
///
/// false → primary = QUAN,  secondary = fiat  (default)
/// true  → primary = fiat,  secondary = QUAN
///
/// To toggle from the swap button:
///   ref.read(isCurrencyFlippedProvider.notifier).toggle();
final isCurrencyFlippedProvider = StateNotifierProvider<IsCurrencyFlippedNotifier, bool>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  return IsCurrencyFlippedNotifier(settings);
});

class IsCurrencyFlippedNotifier extends StateNotifier<bool> {
  final SettingsService _settings;

  IsCurrencyFlippedNotifier(this._settings) : super(_settings.isCurrencyFlipped());

  Future<void> toggle() async {
    final next = !state;
    await _settings.setCurrencyFlipped(next);
    state = next;
  }

  Future<void> setFlipped(bool value) async {
    await _settings.setCurrencyFlipped(value);
    state = value;
  }
}

// ---------------------------------------------------------------------------
// Display state
// ---------------------------------------------------------------------------

/// The fully-resolved display state for the active account's balance.
///
/// Widgets render [primaryAmount] and [secondaryAmount] directly.
/// No conversion math belongs in widgets.
class CurrencyDisplayState {
  final String primaryAmount;
  final String secondaryAmount;
  final bool isFlipped;
  final FiatCurrency selectedFiat;

  const CurrencyDisplayState({
    required this.primaryAmount,
    required this.secondaryAmount,
    required this.isFlipped,
    required this.selectedFiat,
  });

  CurrencyDisplayState copyWith({
    String? primaryAmount,
    String? secondaryAmount,
    bool? isFlipped,
    FiatCurrency? selectedFiat,
  }) => CurrencyDisplayState(
    primaryAmount: primaryAmount ?? this.primaryAmount,
    secondaryAmount: secondaryAmount ?? this.secondaryAmount,
    isFlipped: isFlipped ?? this.isFlipped,
    selectedFiat: selectedFiat ?? this.selectedFiat,
  );
}

// ---------------------------------------------------------------------------
// Balance display provider
// ---------------------------------------------------------------------------

final _hiddenAmountText = '-----';

/// Combines balance, hidden state, flip state, selected fiat, and exchange
/// rate into [CurrencyDisplayState] ready for widgets to render.
final balanceDisplayProvider = Provider<AsyncValue<CurrencyDisplayState>>((ref) {
  final balanceAsync = ref.watch(balanceProvider);
  final isHidden = ref.watch(isBalanceHiddenProvider);
  final isFlipped = ref.watch(isCurrencyFlippedProvider);
  final selectedFiat = ref.watch(selectedFiatCurrencyProvider);
  final xRate = ref.watch(exchangeRateServiceProvider);
  final fmt = ref.watch(numberFormattingServiceProvider);
  final localeConfig = ref.watch(localeNumberConfigProvider);

  return balanceAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
    data: (balance) {
      CurrencyDisplayState data = _toFiatDisplayState(
        balance,
        selectedFiat,
        xRate,
        fmt,
        _hiddenAmountText,
        quanDecimals: 3,
        isFlipped: isFlipped,
        isHidden: isHidden,
        withQuanSymbol: false,
        localeConfig: localeConfig,
      );
      return AsyncValue.data(data);
    },
  );
});

// ---------------------------------------------------------------------------
// Per-amount display provider (for transaction items)
// ---------------------------------------------------------------------------

final txAmountDisplayProvider =
    Provider<
      CurrencyDisplayState Function(
        BigInt, {
        required bool isSend,
        int quanDecimals,
        bool withQuanSymbol,
        bool withSignPrefix,
        String? customHiddenText,
      })
    >((ref) {
      final isHidden = ref.watch(isBalanceHiddenProvider);
      final isFlipped = ref.watch(isCurrencyFlippedProvider);
      final selectedFiat = ref.watch(selectedFiatCurrencyProvider);
      final xRate = ref.watch(exchangeRateServiceProvider);
      final fmt = ref.watch(numberFormattingServiceProvider);
      final localeConfig = ref.watch(localeNumberConfigProvider);

      return (
        BigInt amount, {
        required bool isSend,
        bool withQuanSymbol = true,
        bool withSignPrefix = true,
        int quanDecimals = 2,
        String? customHiddenText,
      }) {
        final hiddenText = customHiddenText ?? _hiddenAmountText;
        final prefix = isSend ? '-' : '+';

        CurrencyDisplayState data = _toFiatDisplayState(
          amount,
          selectedFiat,
          xRate,
          fmt,
          hiddenText,
          quanDecimals: quanDecimals,
          isHidden: isHidden,
          withQuanSymbol: withQuanSymbol,
          isFlipped: isFlipped,
          localeConfig: localeConfig,
        );

        if (!isHidden) {
          data = data.copyWith(primaryAmount: withSignPrefix ? '$prefix${data.primaryAmount}' : data.primaryAmount);
        }

        if (!withQuanSymbol && isFlipped && !isHidden) {
          data = data.copyWith(secondaryAmount: '${data.secondaryAmount} ${AppConstants.tokenSymbol}');
        }

        return data;
      };
    });

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Converts [rawBalance] to a fiat numeric string with the number of decimal
/// places prescribed by [fiat] (e.g. 2 for USD, 0 for JPY/IDR).
/// When [localeConfig] is provided, the output uses locale-appropriate separators.
String _toFiatNumeric(
  BigInt rawBalance,
  FiatCurrency fiat,
  ExchangeRateService xRate, {
  required LocaleNumberConfig localeConfig,
}) {
  final fiatValue = xRate.quanRawToFiat(rawBalance, fiat, AppConstants.decimals);
  final canonical = fiatValue.toStringAsFixed(fiat.decimals);

  return localeConfig.localize(canonical);
}

CurrencyDisplayState _toFiatDisplayState(
  BigInt amount,
  FiatCurrency selectedFiat,
  ExchangeRateService xRate,
  NumberFormattingService fmt,
  String hiddenText, {
  required int quanDecimals,
  required bool isFlipped,
  required bool isHidden,
  required bool withQuanSymbol,
  required LocaleNumberConfig localeConfig,
}) {
  final quanFormatted = fmt.formatBalance(amount, maxDecimals: quanDecimals, addSymbol: withQuanSymbol);
  final fiatFormatted = selectedFiat.format(_toFiatNumeric(amount, selectedFiat, xRate, localeConfig: localeConfig));

  CurrencyDisplayState data = CurrencyDisplayState(
    primaryAmount: isFlipped ? fiatFormatted : quanFormatted,
    secondaryAmount: isFlipped ? quanFormatted : fiatFormatted,
    isFlipped: isFlipped,
    selectedFiat: selectedFiat,
  );

  if (isHidden) {
    data = data.copyWith(primaryAmount: hiddenText, secondaryAmount: hiddenText);
  }

  return data;
}
