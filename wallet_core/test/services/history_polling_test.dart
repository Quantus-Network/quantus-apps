import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/connectivity_provider.dart';
import 'package:wallet_core/providers/shown_balances_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/global_history_polling_service.dart';
import 'package:wallet_core/services/history_polling_manager.dart';
import 'package:wallet_core/utils/polling_refresh_scope.dart';

import '../fakes.dart';

/// An encrypted account whose cached scan can be dropped, once [gate] lets it.
class _FakeEncryptedAccountService extends Fake implements EncryptedAccountService {
  /// How many times the cached scan was dropped.
  int discards = 0;

  /// When set, dropping the cached scan waits for this first.
  Future<void>? gate;

  @override
  Future<void> discardCachedState() async {
    discards++;
    await gate;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  final encrypted = Account(
    walletIndex: 0,
    index: AppConstants.encryptedAccountIndex,
    name: 'Encrypted',
    accountId: encryptedAddress(0),
    accountType: AccountType.encrypted,
  );
  final main = makeAccount(0);
  final savings = makeAccount(1);
  final spending = makeAccount(2);

  late Map<String, int> balanceQueries;
  late _FakeEncryptedAccountService encryptedService;

  /// A wallet of [main], [savings], [spending] and an encrypted account,
  /// with [active] the active one and [shown] the others on screen.
  ProviderContainer wallet({
    required Account active,
    required Set<Account> shown,
    List<Override> overrides = const [],
  }) {
    balanceQueries = {};
    encryptedService = _FakeEncryptedAccountService();
    final bed = WalletTestBed();
    bed.settings.accounts.addAll([main, savings, spending, encrypted]);
    bed.settings.activeAccount = RegularAccount(active);
    final container = ProviderContainer(
      overrides: [
        ...bed.overrides,
        networkStatusProvider.overrideWith((ref) => Stream.value(NetworkStatus.online)),
        encryptedAccountServiceProvider.overrideWith((ref, walletIndex) => encryptedService),
        balanceProviderFamily.overrideWith((ref, accountId) async {
          balanceQueries[accountId] = (balanceQueries[accountId] ?? 0) + 1;
          return BigInt.one;
        }),
        shownBalanceAccountIdsProvider.overrideWithValue({for (final account in shown) account.accountId}),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Puts [account]'s balance on screen, and waits for it.
  Future<void> show(ProviderContainer container, Account account) async {
    final provider = balanceProviderFamily(account.accountId);
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
  }

  /// Waits for the active account to be read from the device. Under a widget
  /// test's clock, [tester] moves time on.
  Future<void> activeAccountLoaded(ProviderContainer container, [WidgetTester? tester]) async {
    while (container.read(activeAccountProvider).value == null) {
      await (tester == null ? Future<void>.delayed(Duration.zero) : tester.pump());
    }
  }

  int queriesOf(Account account) => balanceQueries[account.accountId] ?? 0;

  /// Lets what an invalidation set going finish.
  Future<void> settled() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// The same under a widget test's clock.
  Future<void> settledOn(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  final refProvider = Provider<Ref>((ref) => ref);

  group('the balances on screen besides the active account\'s', () {
    test('none are listed unless the app lists them', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(shownBalanceAccountIdsProvider), isEmpty);
    });

    test('are read again when they are refreshed, the active account\'s left to its own refresh', () async {
      final container = wallet(active: main, shown: {main, savings});
      await activeAccountLoaded(container);
      await show(container, main);
      await show(container, savings);

      invalidateShownAccountBalances(container.read(refProvider));
      await settled();

      expect(queriesOf(savings), 2);
      expect(queriesOf(main), 1);
    });

    test('one nothing is watching is not read', () async {
      final container = wallet(active: main, shown: {savings, spending});
      await activeAccountLoaded(container);
      await show(container, savings);

      invalidateShownAccountBalances(container.read(refProvider));
      await settled();

      expect(queriesOf(savings), 2);
      expect(queriesOf(spending), 0);
    });
  });

  group('a refresh of the active account also refreshes the other balances on screen:', () {
    testWidgets('each poll', (tester) async {
      final container = wallet(active: encrypted, shown: {main, savings});
      await show(container, main);
      await show(container, savings);
      final poller = container.read(globalHistoryPollingServiceProvider);
      await settledOn(tester);

      await tester.pump(GlobalHistoryPollingService.pollInterval);
      await settledOn(tester);

      expect(queriesOf(main), 2);
      expect(queriesOf(savings), 2);

      await tester.pump(GlobalHistoryPollingService.pollInterval);
      await settledOn(tester);

      expect(queriesOf(main), 3);
      expect(queriesOf(savings), 3);

      poller.stopPolling();
    });

    testWidgets('the refresh the person asks for', (tester) async {
      final container = wallet(active: encrypted, shown: {main});
      await activeAccountLoaded(container, tester);
      await show(container, main);

      final manager = container.read(historyPollingManagerProvider);
      await manager.triggerManualRefresh();
      await settledOn(tester);

      expect(queriesOf(main), 2);
      expect(encryptedService.discards, 1);

      manager.stopPolling();
    });

    testWidgets('the refresh on coming back to the app', (tester) async {
      final container = wallet(active: encrypted, shown: {main});
      await activeAccountLoaded(container, tester);
      await show(container, main);

      final manager = container.read(historyPollingManagerProvider);
      await manager.triggerSilentRefresh();
      await settledOn(tester);

      expect(queriesOf(main), 2);
      expect(encryptedService.discards, 0);

      manager.stopPolling();
    });
  });

  testWidgets('a wallet whose accounts were read before the polling was set going is polled all the same', (
    tester,
  ) async {
    final container = wallet(active: encrypted, shown: {main});
    container.listen(accountsProvider, (_, _) {});
    while (container.read(accountsProvider).value == null) {
      await tester.pump();
    }
    await show(container, main);
    final poller = container.read(globalHistoryPollingServiceProvider);
    await settledOn(tester);

    await tester.pump(GlobalHistoryPollingService.pollInterval);
    await settledOn(tester);

    expect(queriesOf(main), 2);

    poller.stopPolling();
  });

  testWidgets('a refresh asked for while one is under way joins it: nothing is refreshed twice', (tester) async {
    final container = wallet(active: encrypted, shown: {main});
    await activeAccountLoaded(container, tester);
    await show(container, main);
    final gate = Completer<void>();
    encryptedService.gate = gate.future;
    final manager = container.read(historyPollingManagerProvider);

    final first = manager.triggerManualRefresh();
    final second = manager.triggerManualRefresh();
    await tester.pump();

    expect(encryptedService.discards, 1);

    gate.complete();
    await Future.wait([first, second]);

    expect(encryptedService.discards, 1);

    // Once it has finished, the next one asked for runs.
    encryptedService.gate = null;
    await manager.triggerManualRefresh();

    expect(encryptedService.discards, 2);

    await settledOn(tester);
    manager.stopPolling();
  });
}
