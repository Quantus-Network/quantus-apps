import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

import '../fakes.dart';

void main() {
  final account = makeAccount(1, accountType: AccountType.encrypted);
  final received = WormholeUtxo(
    transfer: WormholeTransfer(
      id: 'r1',
      blockHeight: 7,
      timestamp: DateTime.utc(2026, 9, 1),
      fromId: 'qzsender',
      toId: account.accountId,
      amount: wormholeTokenFromScaled(250),
      toHash: '',
      leafIndex: BigInt.zero,
      transferCount: BigInt.zero,
      extrinsicId: '0xpay',
    ),
    owner: WormholeAddressInfo(index: 0, address: account.accountId, secretHex: ''),
    nullifierHex: '0xn1',
  );
  final state = EncryptedAccountState(
    accountId: account.accountId,
    ownAddresses: {account.accountId},
    received: [received],
    spends: const {},
    utxos: [received],
    pendingChangeToken: BigInt.zero,
    nextIndex: 1,
    nextChangeIndex: 0,
  );

  test('an encrypted account lists its wormhole history unpaged', () async {
    final settings = FakeSettingsService(activeAccount: RegularAccount(account));
    final container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWithValue(settings),
        activeAccountProvider.overrideWith((ref) => ActiveAccountNotifier(settings)),
        encryptedStateProvider.overrideWith((ref, walletIndex) async => state),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(activeAccountTransactionsProvider(TransactionFilter.all), (_, _) {});

    while (!sub.read().hasValue) {
      await Future<void>.delayed(Duration.zero);
    }

    final rows = sub.read().requireValue.otherTransfers;
    expect(rows.map((e) => e.id), ['r1']);
    expect(rows.single.to, account.accountId);
    expect(rows.single.amount, received.amount);
    expect(container.read(activeAccountPaginationProvider(TransactionFilter.all)), isNull);
  });
}
