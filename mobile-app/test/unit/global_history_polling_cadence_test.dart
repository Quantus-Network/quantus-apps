import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/global_history_polling_service.dart';

import '../fakes.dart';

void main() {
  const minute = Duration(minutes: 1);
  const s15 = Duration(seconds: 15);
  const s30 = Duration(seconds: 30);

  EncryptedAccountState stateWithPending(Account account, BigInt pending) => EncryptedAccountState(
    accountId: account.accountId,
    ownAddresses: {account.accountId},
    received: const [],
    spends: const {},
    utxos: const [],
    pendingChangeToken: pending,
    nextIndex: 1,
    nextChangeIndex: 0,
  );

  group('activeEncryptedPendingProvider', () {
    test('is the pending change of an active encrypted account', () async {
      final account = makeAccount(1, accountType: AccountType.encrypted);
      final settings = FakeSettingsService(activeAccount: RegularAccount(account));
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWithValue(settings),
          activeAccountProvider.overrideWith((ref) => ActiveAccountNotifier(settings)),
          encryptedStateProvider.overrideWith((ref, walletIndex) async => stateWithPending(account, BigInt.from(7))),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(activeEncryptedPendingProvider, (_, _) {});

      while (sub.read() == BigInt.zero) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(sub.read(), BigInt.from(7));
    });

    test('is zero for a transparent account', () async {
      final account = makeAccount(1);
      final settings = FakeSettingsService(activeAccount: RegularAccount(account));
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWithValue(settings),
          activeAccountProvider.overrideWith((ref) => ActiveAccountNotifier(settings)),
          encryptedStateProvider.overrideWith((ref, walletIndex) async => fail('must not load encrypted state')),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(activeEncryptedPendingProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(sub.read(), BigInt.zero);
    });
  });

  group('poll cadence', () {
    test('pollDelay backs off from 15s and settles at a minute while change is pending', () {
      Duration delay(int polls) => GlobalHistoryPollingService.pollDelay(pending: BigInt.one, pollsWhilePending: polls);
      expect([for (var i = 0; i < 5; i++) delay(i)], [s15, s30, minute, minute, minute]);
      expect(GlobalHistoryPollingService.pollDelay(pending: BigInt.zero, pollsWhilePending: 0), minute);
    });

    GlobalHistoryPollingService serviceOffline() {
      final serviceProvider = Provider(GlobalHistoryPollingService.new);
      final container = ProviderContainer(overrides: [isOnlineProvider.overrideWithValue(false)]);
      addTearDown(container.dispose);
      final service = container.read(serviceProvider);
      addTearDown(service.dispose);
      return service;
    }

    Duration scheduled(FakeAsync async) => async.pendingTimers.single.duration;

    test('a send shortens the next poll and each poll waiting for change doubles it', () {
      fakeAsync((async) {
        final service = serviceOffline();
        service.startPolling();
        expect(scheduled(async), minute);

        service.pendingChangeUpdated(BigInt.from(5));
        expect(scheduled(async), s15);

        async.elapse(s15);
        expect(scheduled(async), s30);
        async.elapse(s30);
        expect(scheduled(async), minute);
        async.elapse(minute);
        expect(scheduled(async), minute);
      });
    });

    test('another send restarts the cadence; arrived change returns to the minute poll', () {
      fakeAsync((async) {
        final service = serviceOffline();
        service.startPolling();
        service.pendingChangeUpdated(BigInt.from(5));
        async.elapse(s15);
        async.elapse(s30);
        expect(scheduled(async), minute);

        service.pendingChangeUpdated(BigInt.from(12));
        expect(scheduled(async), s15);

        service.pendingChangeUpdated(BigInt.zero);
        expect(scheduled(async), minute);
      });
    });

    test('the same pending amount reported again does not reset the backoff', () {
      fakeAsync((async) {
        final service = serviceOffline();
        service.startPolling();
        service.pendingChangeUpdated(BigInt.from(5));
        async.elapse(s15);
        expect(scheduled(async), s30);
        async.elapse(const Duration(seconds: 10));

        service.pendingChangeUpdated(BigInt.from(5));
        // The 30s timer from t=15 fires at t=45; a reset 15s timer would have
        // fired at t=40 and scheduled 30s instead.
        async.elapse(const Duration(seconds: 20));
        expect(scheduled(async), minute);
      });
    });

    test('a pending update while paused does not start a timer', () {
      fakeAsync((async) {
        final service = serviceOffline();
        service.startPolling();
        service.pausePolling();
        service.pendingChangeUpdated(BigInt.from(5));
        expect(async.pendingTimers, isEmpty);

        service.resumePolling();
        expect(scheduled(async), s15);
      });
    });
  });
}
