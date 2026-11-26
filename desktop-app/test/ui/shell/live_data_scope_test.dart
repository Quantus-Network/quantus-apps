import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/welcome_page.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/app_lifecycle_state_provider.dart';
import 'package:wallet_core/providers/shown_balances_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/global_history_polling_service.dart';

import '../../fakes.dart';

/// Opens the window on a wallet whose active account is Main.
Future<void> _openWallet(WidgetTester tester, {required FakeHistoryPollingManager polling, FakeNetwork? network}) {
  return pumpShell(
    tester,
    polling: polling,
    network: network,
    overrides: shellOverrides(
      accounts: const [mainAccount, savingsAccount, encryptedAccount, vaultAccount],
      settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount), multisigs: [teamMultisig]),
      balances: {...oneTokenEach, teamMultisig.accountId: oneToken},
      encryptedBalances: {0: oneToken},
    ),
  );
}

/// Tells the app its window is [state], as the system would.
Future<void> _window(WidgetTester tester, AppLifecycleState state) async {
  addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
  tester.binding.handleAppLifecycleStateChanged(state);
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

/// The Encrypted account's state, counting each time it is loaded.
class _CountedStates extends MapView<int, EncryptedAccountState> {
  _CountedStates(super.map);

  int reads = 0;

  @override
  EncryptedAccountState? operator [](Object? key) {
    reads++;
    return super[key];
  }
}

void main() {
  testOnMac('opening the wallet sets the polling going, and asks nothing more of it', (tester) async {
    final polling = FakeHistoryPollingManager();

    await _openWallet(tester, polling: polling);

    expect(find.byType(Sidebar), findsOneWidget);
    expect(polling.starts, 1);
    expect(polling.calls, isEmpty);
  });

  testOnMac('an opened wallet is polled each minute by the app\'s own polling', (tester) async {
    var mainQueries = 0;
    // The shell's fake indexer has no history for any account.
    await pumpShell(
      tester,
      realPolling: true,
      overrides: shellOverrides(
        accounts: const [mainAccount, savingsAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balanceOf: (accountId) async {
          if (accountId == mainAccount.accountId) mainQueries++;
          return oneToken;
        },
      ),
    );

    expect(mainQueries, 1);

    await tester.pump(GlobalHistoryPollingService.pollInterval);
    await tester.pumpAndSettle();

    expect(mainQueries, 2);
  });

  testOnMac('before there is a wallet nothing is polled', (tester) async {
    final polling = FakeHistoryPollingManager();

    await pumpShell(tester, polling: polling, overrides: FakeWalletDevice().overrides);

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(polling.starts, 0);
  });

  testOnMac('a window that is minimized or hidden keeps polling, so that what the wallet watches for is still '
      'noticed', (tester) async {
    final polling = FakeHistoryPollingManager();
    await _openWallet(tester, polling: polling);

    await _window(tester, AppLifecycleState.hidden);

    expect(polling.calls, isEmpty);

    await _window(tester, AppLifecycleState.inactive);
    await _window(tester, AppLifecycleState.resumed);

    expect(polling.calls, isEmpty);
  });

  testOnMac('a window that only loses the focus keeps polling', (tester) async {
    final polling = FakeHistoryPollingManager();
    await _openWallet(tester, polling: polling);

    await _window(tester, AppLifecycleState.inactive);
    await _window(tester, AppLifecycleState.resumed);

    expect(polling.calls, isEmpty);
  });

  testOnMac('what pauses with the app in the background runs while the window is on screen, focused or not', (
    tester,
  ) async {
    await _openWallet(tester, polling: FakeHistoryPollingManager());
    AppLifecycleState shared() => _container(tester).read(appLifecycleStateProvider);

    await _window(tester, AppLifecycleState.inactive);

    expect(shared(), AppLifecycleState.resumed);

    await _window(tester, AppLifecycleState.hidden);

    expect(shared(), AppLifecycleState.hidden);

    await _window(tester, AppLifecycleState.inactive);

    expect(shared(), AppLifecycleState.resumed);
  });

  testOnMac('losing the network pauses the polling; back online, it resumes and catches up at once', (tester) async {
    final polling = FakeHistoryPollingManager();
    final network = FakeNetwork();
    await _openWallet(tester, polling: polling, network: network);

    network.goOffline();
    await tester.pumpAndSettle();

    expect(polling.calls, ['pause']);

    network.goOnline();
    await tester.pumpAndSettle();

    expect(polling.calls, ['pause', 'resume', 'silentRefresh']);
  });

  testOnMac('the network coming back while the window is hidden resumes the polling at once', (tester) async {
    final polling = FakeHistoryPollingManager();
    final network = FakeNetwork();
    await _openWallet(tester, polling: polling, network: network);

    network.goOffline();
    await tester.pumpAndSettle();
    await _window(tester, AppLifecycleState.hidden);
    network.goOnline();
    await tester.pumpAndSettle();

    expect(polling.calls, ['pause', 'resume', 'silentRefresh']);

    // Shown again, it is already caught up.
    await _window(tester, AppLifecycleState.inactive);

    expect(polling.calls, ['pause', 'resume', 'silentRefresh']);
  });

  testOnMac('a window shown again while the network is down stays paused until it is back', (tester) async {
    final polling = FakeHistoryPollingManager();
    final network = FakeNetwork();
    await _openWallet(tester, polling: polling, network: network);

    await _window(tester, AppLifecycleState.hidden);
    network.goOffline();
    await tester.pumpAndSettle();
    await _window(tester, AppLifecycleState.inactive);

    expect(polling.calls, ['pause']);

    network.goOnline();
    await tester.pumpAndSettle();

    expect(polling.calls, ['pause', 'resume', 'silentRefresh']);
  });

  group('with the window closed', () {
    void setClosed(WidgetTester tester, bool isClosed) =>
        _container(tester).read(windowClosedProvider.notifier).set(isClosed);

    testOnMac('no poll reloads the active Encrypted account, which would read its recovery phrase', (tester) async {
      final states = _CountedStates({
        0: encryptedHolding(const [1250]),
      });
      await pumpShell(
        tester,
        realPolling: true,
        overrides: shellOverrides(
          accounts: const [mainAccount, encryptedAccount],
          settings: FakeSettingsService(activeAccount: const RegularAccount(encryptedAccount)),
          balances: oneTokenEach,
          encryptedBalances: {0: oneToken},
          encryptedStates: states,
        ),
      );
      final watching = _container(tester).listen(encryptedStateProvider(0), (_, _) {});
      addTearDown(watching.close);

      var before = states.reads;
      await tester.pump(GlobalHistoryPollingService.pollInterval);
      await tester.pumpAndSettle();
      expect(states.reads, greaterThan(before), reason: 'an open window is polled, so this test can see a reload');

      setClosed(tester, true);
      await tester.pump();
      before = states.reads;
      await tester.pump(GlobalHistoryPollingService.pollInterval * 3);
      await tester.pumpAndSettle();

      expect(states.reads, before);
    });

    testOnMac('the polling pauses, and on reopening resumes and catches up', (tester) async {
      final polling = FakeHistoryPollingManager();
      await _openWallet(tester, polling: polling);

      setClosed(tester, true);
      await tester.pumpAndSettle();
      expect(polling.calls, ['pause']);

      setClosed(tester, false);
      await tester.pumpAndSettle();
      expect(polling.calls, ['pause', 'resume', 'silentRefresh']);
    });

    testOnMac('the network coming back does not resume it', (tester) async {
      final polling = FakeHistoryPollingManager();
      final network = FakeNetwork();
      await _openWallet(tester, polling: polling, network: network);
      setClosed(tester, true);
      await tester.pumpAndSettle();

      network.goOffline();
      await tester.pumpAndSettle();
      network.goOnline();
      await tester.pumpAndSettle();

      expect(polling.calls, ['pause']);
    });

    testOnMac('reopening while offline stays paused until the network is back', (tester) async {
      final polling = FakeHistoryPollingManager();
      final network = FakeNetwork();
      await _openWallet(tester, polling: polling, network: network);
      setClosed(tester, true);
      await tester.pumpAndSettle();
      network.goOffline();
      await tester.pumpAndSettle();

      setClosed(tester, false);
      await tester.pumpAndSettle();
      expect(polling.calls, ['pause']);

      network.goOnline();
      await tester.pumpAndSettle();
      expect(polling.calls, ['pause', 'resume', 'silentRefresh']);
    });
  });

  testOnMac('a wallet wiped while its polling is paused leaves the polling unpaused for the next one', (tester) async {
    final polling = FakeHistoryPollingManager();
    final network = FakeNetwork();
    final device = FakeWalletDevice()..store(const [mainAccount]);
    await pumpShell(tester, polling: polling, network: network, overrides: device.overrides);

    network.goOffline();
    await tester.pumpAndSettle();
    await _container(tester).read(walletPresenceProvider.notifier).wipeWallet();
    await tester.pumpAndSettle();

    expect(find.byType(WelcomePage), findsOneWidget);
    // Unpaused only: there is no wallet left to catch up on.
    expect(polling.calls, ['pause', 'resume']);
  });

  testOnMac('a catch-up that fails leaves the app running, the polling resumed', (tester) async {
    final polling = FakeHistoryPollingManager()..refreshError = StateError('the node did not answer');
    final network = FakeNetwork();
    await _openWallet(tester, polling: polling, network: network);

    network.goOffline();
    await tester.pumpAndSettle();
    network.goOnline();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(polling.calls, ['pause', 'resume', 'silentRefresh']);
    expect(find.byType(Sidebar), findsOneWidget);
  });

  testOnMac('the balances refreshed with the active account\'s are the sidebar\'s other accounts\', all but the '
      'encrypted one\'s, which comes from its own scan', (tester) async {
    await _openWallet(tester, polling: FakeHistoryPollingManager());

    expect(_container(tester).read(shownBalanceAccountIdsProvider), {
      mainAccount.accountId,
      savingsAccount.accountId,
      vaultAccount.accountId,
      teamMultisig.accountId,
    });
  });
}
