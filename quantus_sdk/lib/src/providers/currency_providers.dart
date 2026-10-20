import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/models/fiat_currency.dart';
import 'package:quantus_sdk/src/services/exchange_rate_service.dart';
import 'package:quantus_sdk/src/providers/service_providers.dart';
import 'package:quantus_sdk/src/providers/swap_providers.dart';

final exchangeRatesStoreProvider = Provider<ExchangeRatesStore>((ref) {
  return ExchangeRatesStore(ref.watch(settingsServiceProvider));
});

/// Live USD-based exchange rates: fresh cache, else a fetch, else the stale
/// cache or the static fallback.
final exchangeRatesProvider = FutureProvider<Map<String, Decimal>>((ref) {
  return ref.read(exchangeRatesStoreProvider).load(QuersiService());
});

/// QTC's USD price, refreshed every [TokenPriceService.refreshInterval].
final tokenUsdPriceProvider = StreamProvider<Decimal>((ref) {
  return TokenPriceService.watchUsdPrice(ref.watch(swapServiceProvider));
});

/// Rates for conversions: the last persisted rates while live ones load, the
/// live ones once they arrive, and QTC's USD price once one is known.
final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  final ratesAsync = ref.watch(exchangeRatesProvider);
  final store = ref.read(exchangeRatesStoreProvider);
  final tokenToUsdRate = ref.watch(tokenUsdPriceProvider).value;

  ExchangeRateService service(Map<String, Decimal> rates) =>
      ExchangeRateService(rates: rates, tokenToUsdRate: tokenToUsdRate);

  return ratesAsync.when(
    data: service,
    loading: () => service(store.readAnyAge()),
    error: (_, _) => service(store.readAnyAge()),
  );
});

/// The user's fiat currency for conversions; USD until one is chosen.
final selectedFiatCurrencyProvider = StateNotifierProvider<SelectedFiatCurrencyNotifier, FiatCurrency>((ref) {
  return SelectedFiatCurrencyNotifier(ref.watch(settingsServiceProvider));
});

class SelectedFiatCurrencyNotifier extends StateNotifier<FiatCurrency> {
  final SettingsService _settings;

  static const FiatCurrency _defaultCurrency = FiatCurrency.usd;

  SelectedFiatCurrencyNotifier(this._settings) : super(_load(_settings));

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
    return code == null ? _defaultCurrency : FiatCurrency.fromCode(code);
  }
}
