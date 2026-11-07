import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/filtered_transactions_params.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final encrypted = makeAccount(1, accountType: AccountType.encrypted);
  final transparent = makeAccount(2);

  EncryptedAccountState snapshot(BigInt amount) {
    final utxo = WormholeUtxo(
      transfer: WormholeTransfer(
        id: 'r1',
        blockHeight: 7,
        timestamp: DateTime.utc(2026, 9, 1),
        fromId: 'qzsender',
        toId: encrypted.accountId,
        amount: amount,
        toHash: '',
        leafIndex: BigInt.zero,
        transferCount: BigInt.zero,
        extrinsicId: '0xpay',
        viaWormhole: false,
      ),
      owner: WormholeAddressInfo(index: 0, address: encrypted.accountId, secretHex: ''),
      nullifierHex: '0xn1',
    );
    return EncryptedAccountState(
      accountId: encrypted.accountId,
      ownAddresses: {encrypted.accountId},
      received: [utxo],
      spends: const {},
      utxos: [utxo],
      pendingChangeToken: BigInt.zero,
      nextIndex: 1,
      nextChangeIndex: 0,
    );
  }

  ProviderContainer containerFor(Account active, {List<Override> overrides = const []}) {
    final settings = FakeSettingsService(activeAccount: RegularAccount(active));
    final container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWithValue(settings),
        activeAccountProvider.overrideWith((ref) => ActiveAccountNotifier(settings)),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle(ProviderContainer container) async {
    while (container.read(activeAccountProvider).value == null) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  FilteredTransactionsParams paramsFor(Account account) => FilteredTransactionsParams(
    accountIds: AccountIdListCache.get([account.accountId]),
    filter: TransactionFilter.all,
  );

  group('activePaginatedAccountId', () {
    test('names a transparent active account', () async {
      final container = containerFor(transparent);
      await settle(container);
      final probe = Provider((ref) => (activeAccountId(ref), activePaginatedAccountId(ref)));
      expect(container.read(probe), (transparent.accountId, transparent.accountId));
    });

    test('is null for an encrypted active account, whose history is in its snapshot', () async {
      final container = containerFor(encrypted);
      await settle(container);
      final probe = Provider((ref) => (activeAccountId(ref), activePaginatedAccountId(ref)));
      expect(container.read(probe), (encrypted.accountId, null));
    });
  });

  test('a poll of an encrypted account does not open a transparent history controller', () async {
    final container = containerFor(encrypted);
    await settle(container);
    final probe = Provider((ref) => ref);
    final ref = container.read(probe);

    await silentRefreshActiveAccount(ref);
    await refreshActiveAccountOnSwitch(ref);

    expect(container.exists(filteredPaginationControllerProviderFamily(paramsFor(encrypted))), isFalse);
  });

  group('activeBalanceProvider', () {
    test('serves an encrypted account from its snapshot without a transparent balance query', () async {
      final container = containerFor(
        encrypted,
        overrides: [
          encryptedStateProvider.overrideWith((ref, walletIndex) async => snapshot(BigInt.from(100))),
          balanceProviderFamily.overrideWith((ref, accountId) async => fail('transparent balance queried')),
        ],
      );
      final sub = container.listen(activeBalanceProvider, (_, _) {});
      while (!sub.read().hasValue) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(sub.read().requireValue, BigInt.from(100));
    });

    test('serves a transparent account from the chain balance', () async {
      final container = containerFor(
        transparent,
        overrides: [
          encryptedStateProvider.overrideWith((ref, walletIndex) async => fail('encrypted snapshot loaded')),
          balanceProviderFamily.overrideWith((ref, accountId) async => BigInt.from(42)),
        ],
      );
      final sub = container.listen(activeBalanceProvider, (_, _) {});
      while (!sub.read().hasValue) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(sub.read().requireValue, BigInt.from(42));
    });
  });
}
