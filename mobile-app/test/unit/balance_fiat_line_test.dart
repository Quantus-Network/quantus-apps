import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  final oneAndAHalf = BigInt.from(15) * BigInt.from(10).pow(11);

  ProviderContainer container({Decimal? price}) {
    final c = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(makeAccount(1)))),
        balanceProvider.overrideWithValue(AsyncValue.data(oneAndAHalf)),
        exchangeRatesProvider.overrideWith((ref) async => {'USD': Decimal.one}),
        tokenUsdPriceProvider.overrideWith(
          (ref) => price == null ? const Stream<Decimal>.empty() : Stream.value(price),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Listens, which is what runs the stream, and waits for the rates and any price to land.
  Future<ProviderContainer> ready({Decimal? price}) async {
    final c = container(price: price);
    c.listen(balanceDisplayProvider, (_, _) {});
    await c.read(exchangeRatesProvider.future);
    if (price != null) await c.read(tokenUsdPriceProvider.future);
    return c;
  }

  test('the balance carries no fiat amount until QTC has a price', () async {
    final c = await ready();
    expect(c.read(balanceDisplayProvider).requireValue.secondaryAmount, isNull);
  });

  test('the balance is priced in the selected fiat once QTC has a price', () async {
    final c = await ready(price: Decimal.parse('2'));
    expect(c.read(balanceDisplayProvider).requireValue.secondaryAmount, r'$3.00');
  });

  test('transaction amounts carry no fiat amount', () async {
    final c = await ready(price: Decimal.parse('2'));
    expect(c.read(txAmountDisplayProvider)(oneAndAHalf, isSend: true).secondaryAmount, isNull);
  });

  testWidgets('the fiat line shows under the amount and hides with it', (tester) async {
    const priced = CurrencyDisplayState(
      primaryAmount: '1.5',
      secondaryAmount: r'$3.00',
      selectedFiat: FiatCurrency.usd,
    );
    await tester.pumpApp(const AmountDisplayWithConversion(amountDisplay: priced));
    expect(find.text(r'≈ $3.00'), findsOneWidget);

    await tester.pumpApp(const AmountDisplayWithConversion(amountDisplay: priced, isHidden: true));
    expect(find.text('≈ $hiddenAmountText'), findsOneWidget);

    const unpriced = CurrencyDisplayState(primaryAmount: '1.5', selectedFiat: FiatCurrency.usd);
    await tester.pumpApp(const AmountDisplayWithConversion(amountDisplay: unpriced));
    expect(find.textContaining('≈'), findsNothing);
  });
}
