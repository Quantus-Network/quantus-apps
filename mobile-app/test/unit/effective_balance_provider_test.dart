import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const accountId = 'account-a';

  ProviderContainer makeContainer({required Future<BigInt> Function() fetch}) {
    final container = ProviderContainer(
      // No auto-retry: let a failed fetch reach its terminal error state.
      retry: (retryCount, error) => null,
      overrides: [balanceProviderFamily.overrideWith((ref, accountId) => fetch())],
    );
    addTearDown(container.dispose);
    // Riverpod pauses unlistened providers; keep the chain active.
    container.listen(effectiveBalanceProviderFamily(accountId), (_, _) {});
    return container;
  }

  test('keeps the last fetched balance when a refresh errors', () async {
    var fail = false;
    final container = makeContainer(fetch: () async => fail ? throw Exception('rpc down') : BigInt.from(100));

    await pumpEventQueue();
    expect(container.read(effectiveBalanceProviderFamily(accountId)).value, BigInt.from(100));

    fail = true;
    container.invalidate(balanceProviderFamily(accountId));
    await pumpEventQueue();

    expect(container.read(balanceProviderFamily(accountId)).hasError, isTrue);
    expect(container.read(effectiveBalanceProviderFamily(accountId)).value, BigInt.from(100));
  });

  test('propagates an error that happens before any successful fetch', () async {
    final container = makeContainer(fetch: () async => throw Exception('rpc down'));

    await pumpEventQueue();

    final result = container.read(effectiveBalanceProviderFamily(accountId));
    expect(result.hasError, isTrue);
    expect(result.value, isNull);
  });
}
