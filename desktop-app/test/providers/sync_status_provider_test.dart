import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/sync_status_provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../fakes.dart';

void main() {
  final firstRead = DateTime(2026, 11, 19, 14, 2);
  final laterRead = DateTime(2026, 11, 19, 14, 3);

  late DateTime now;

  /// Each read of a balance waits for the next of these, which the test answers.
  late List<Completer<BigInt>> reads;

  /// A wallet whose active account is [active], with [mainAccount] and
  /// [savingsAccount] in it; its balances answer as the test says.
  Future<ProviderContainer> wallet({
    Account active = mainAccount,
    Map<int, BigInt> encryptedBalances = const {},
  }) async {
    now = firstRead;
    reads = [];
    final container = ProviderContainer(
      overrides: [
        ...shellOverrides(
          accounts: const [mainAccount, savingsAccount, encryptedAccount],
          settings: FakeSettingsService(activeAccount: RegularAccount(active)),
          balanceOf: (accountId) {
            final read = Completer<BigInt>();
            reads.add(read);
            return read.future;
          },
          encryptedBalances: encryptedBalances,
        ),
        currentTimeProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    container.listen(syncStatusProvider, (_, _) {});
    while (container.read(activeAccountProvider).value == null) {
      await pumpEventQueue();
    }
    await pumpEventQueue();
    return container;
  }

  SyncStatus status(ProviderContainer container) => container.read(syncStatusProvider);

  Future<void> answer(int read, {BigInt? balance, Object? error}) async {
    if (error != null) {
      reads[read].completeError(error);
    } else {
      reads[read].complete(balance ?? oneToken);
    }
    await pumpEventQueue();
  }

  test('while the active account\'s balance is read it is syncing; once read, it is synced at that time', () async {
    final container = await wallet();

    expect(status(container), const SyncStatus(isSyncing: true));

    await answer(0);

    expect(status(container), SyncStatus(lastSyncedAt: firstRead));
  });

  test('reading it again is syncing again, then synced at the new time', () async {
    final container = await wallet();
    await answer(0);

    now = laterRead;
    container.invalidate(balanceProviderFamily(mainAccount.accountId));
    await pumpEventQueue();

    expect(status(container), SyncStatus(isSyncing: true, lastSyncedAt: firstRead));

    await answer(1);

    expect(status(container), SyncStatus(lastSyncedAt: laterRead));
  });

  test('a read that fails ends the syncing, says it failed, and keeps the time of the last good one', () async {
    final container = await wallet();
    await answer(0);

    now = laterRead;
    container.invalidate(balanceProviderFamily(mainAccount.accountId));
    await pumpEventQueue();
    await answer(1, error: StateError('the node did not answer'));

    expect(status(container), SyncStatus(lastSyncedAt: firstRead, hasFailed: true));

    // The next good read clears it.
    container.invalidate(balanceProviderFamily(mainAccount.accountId));
    await pumpEventQueue();
    await answer(2);

    expect(status(container), SyncStatus(lastSyncedAt: laterRead));
  });

  test('switching to an account whose balance was read before is no new read', () async {
    final container = await wallet();
    await answer(0);
    // The sidebar has read Savings' balance as well.
    container.listen(balanceProviderFamily(savingsAccount.accountId), (_, _) {});
    await pumpEventQueue();
    await answer(1);

    now = laterRead;
    await container.read(activeAccountProvider.notifier).setActiveAccount(const RegularAccount(savingsAccount));
    await pumpEventQueue();

    expect(status(container).lastSyncedAt, firstRead);
  });

  test('on the encrypted account it follows the account\'s own balance', () async {
    final container = await wallet(active: encryptedAccount, encryptedBalances: {0: oneToken});

    expect(status(container), SyncStatus(lastSyncedAt: firstRead));
  });
}
