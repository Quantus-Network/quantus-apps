import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const accountId = 'account-a';

  ProviderContainer makeContainer({required Future<BigInt> Function() fetch}) {
    final container = ProviderContainer(
      overrides: [balanceProviderFamily.overrideWith((ref, accountId) => fetch())],
    );
    addTearDown(container.dispose);
    // Riverpod pauses unlistened providers; keep the chain active.
    container.listen(balanceProviderFamily(accountId), (_, _) {});
    container.listen(effectiveBalanceProviderFamily(accountId), (_, _) {});
    return container;
  }

  test('keeps the last fetched balance when a refresh errors', () async {
    var fail = false;
    final container = makeContainer(fetch: () async => fail ? throw Exception('rpc down') : BigInt.from(100));

    await container.read(balanceProviderFamily(accountId).future);
    expect(container.read(effectiveBalanceProviderFamily(accountId)).value, BigInt.from(100));

    fail = true;
    container.invalidate(balanceProviderFamily(accountId));
    await expectLater(container.read(balanceProviderFamily(accountId).future), throwsA(anything));

    expect(container.read(effectiveBalanceProviderFamily(accountId)).value, BigInt.from(100));
  });

  test('propagates an error that happens before any successful fetch', () async {
    final container = makeContainer(fetch: () async => throw Exception('rpc down'));

    await expectLater(container.read(balanceProviderFamily(accountId).future), throwsA(anything));

    final result = container.read(effectiveBalanceProviderFamily(accountId));
    expect(result.hasError, isTrue);
    expect(result.value, isNull);
  });
}
