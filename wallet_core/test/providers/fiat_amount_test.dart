import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_core/models/fiat_currency.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../fakes.dart';

/// Settings with no rates saved and [currency] chosen.
class _CurrencySettings extends FakeSettingsService {
  _CurrencySettings(this.currency);

  final FiatCurrency? currency;

  @override
  String? getString(String key) => null;

  @override
  String? getSelectedFiatCurrency() => currency?.code;
}

void main() {
  /// 1.5 QTC.
  final oneAndAHalf = BigInt.from(15) * BigInt.from(10).pow(11);

  /// What [fiatAmountWith] says of [amount] once the rates, and QTC's [price]
  /// when there is one, have landed, with [currency] chosen.
  Future<String?> fiatAmountOf(
    BigInt amount, {
    Decimal? price,
    FiatCurrency? currency,
    Map<String, Decimal>? rates,
  }) async {
    final container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWithValue(_CurrencySettings(currency)),
        exchangeRatesProvider.overrideWith((ref) async => rates ?? {'USD': Decimal.one}),
        tokenUsdPriceProvider.overrideWith(
          (ref) => price == null ? const Stream<Decimal>.empty() : Stream.value(price),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(exchangeRateServiceProvider, (_, _) {});
    await container.read(exchangeRatesProvider.future);
    if (price != null) await container.read(tokenUsdPriceProvider.future);
    return fiatAmountWith(container.read, amount);
  }

  test('is null until QTC has a price', () async {
    expect(await fiatAmountOf(oneAndAHalf), isNull);
  });

  test('is the amount in dollars at QTC\'s price', () async {
    expect(await fiatAmountOf(oneAndAHalf, price: Decimal.fromInt(2)), r'$3.00');
  });

  test('follows the chosen currency\'s rate and decimals', () async {
    expect(
      await fiatAmountOf(
        oneAndAHalf,
        price: Decimal.fromInt(2),
        currency: FiatCurrency.idr,
        rates: {'USD': Decimal.one, 'IDR': Decimal.fromInt(16000)},
      ),
      'Rp48,000',
    );
  });
}
