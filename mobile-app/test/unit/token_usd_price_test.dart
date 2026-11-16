import 'package:decimal/decimal.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/app_lifecycle_state_provider.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';

class _ListingSwapService extends SwapService {
  int reads = 0;

  @override
  Future<SwapToken?> getListedQuantusToken() async {
    reads++;
    return SwapToken(
      assetId: 'nep141:qtc.omft.near',
      symbol: 'QTC',
      network: SwapToken.quantusNetwork,
      decimals: AppConstants.decimals,
      usdPrice: reads / 10,
      isQuantus: true,
    );
  }
}

void main() {
  test('QTC is priced on launch and on each return to the foreground, never on a timer', () {
    fakeAsync((async) {
      final swap = _ListingSwapService();
      final container = ProviderContainer(overrides: [swapServiceProvider.overrideWithValue(swap)]);
      final price = container.listen(tokenUsdPriceProvider, (_, _) {});
      void lifecycle(AppLifecycleState state) {
        container.read(appLifecycleStateProvider.notifier).state = state;
        async.elapse(Duration.zero);
      }

      async.elapse(Duration.zero);
      expect(swap.reads, 1);
      expect(price.read().value, Decimal.parse('0.1'));

      async.elapse(const Duration(hours: 1));
      expect(swap.reads, 1);

      lifecycle(AppLifecycleState.inactive);
      lifecycle(AppLifecycleState.hidden);
      lifecycle(AppLifecycleState.paused);
      async.elapse(const Duration(hours: 1));
      expect(swap.reads, 1);

      lifecycle(AppLifecycleState.hidden);
      lifecycle(AppLifecycleState.inactive);
      lifecycle(AppLifecycleState.resumed);
      expect(swap.reads, 2);
      expect(price.read().value, Decimal.parse('0.2'));
      container.dispose();
    });
  });
}
