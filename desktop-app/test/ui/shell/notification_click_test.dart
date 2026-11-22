import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_account_transactions_provider.dart';
import 'package:wallet_core/providers/filtered_all_transactions_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/services/pending_transaction_polling_service.dart';
import 'package:wallet_core/services/telemetry.dart';

import '../../fakes.dart';
import '../../services/fake_notification_plugin.dart';

class _RecordingTelemetry implements Telemetry {
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

const _hash = '0xclicked';
final _when = DateTime(2026, 11, 21, 12);

/// Opens the window on a wallet whose active account is Main, its accounts
/// loaded by [loadAccounts] when given.
Future<ProviderContainer> _openWallet(
  WidgetTester tester,
  FakeNotificationPlugin notifications, {
  Future<List<Account>> Function()? loadAccounts,
  bool settle = true,
  FakeSendChain? chain,
  List<MultisigAccount> multisigs = const [],
}) async {
  await pumpShell(
    tester,
    notifications: notifications,
    settle: settle,
    overrides: shellOverrides(
      accounts: const [mainAccount, savingsAccount],
      loadAccounts: loadAccounts,
      chain: chain,
      settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount), multisigs: multisigs),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
}

/// What a notification about [accountId] carries.
String _about(String accountId) => jsonEncode({'accountId': accountId});

/// What a notification about the transaction [hash] in [accountId] carries.
String _aboutTransaction(String accountId, {String hash = _hash}) =>
    jsonEncode({'accountId': accountId, 'extrinsicHash': hash});

String? _activeAccountId(ProviderContainer container) => container.read(activeAccountProvider).value?.account.accountId;

OpenedActivity? _opened(ProviderContainer container) => container.read(openedActivityViewProvider);

TransferEvent _transfer({String hash = _hash, String id = 'indexed-send'}) => TransferEvent(
  id: id,
  from: mainAccount.accountId,
  to: 'qzBob',
  amount: oneToken,
  timestamp: _when,
  fee: BigInt.zero,
  extrinsicHash: hash,
  blockNumber: 10,
  blockHash: '0xblock',
);

MultisigProposal _proposal({MultisigProposalStatus status = MultisigProposalStatus.active}) => MultisigProposal(
  entityId: 'proposal-1',
  id: 1,
  multisigAddress: teamMultisig.accountId,
  proposer: mainAccount.accountId,
  createdAt: _when,
  updatedAt: _when,
  pallet: '',
  call: '',
  recipient: 'qzBob',
  amount: oneToken,
  expiryBlock: 1284220,
  approvals: const ['qzMain'],
  deposit: oneToken,
  status: status,
  threshold: teamMultisig.threshold,
  signerCount: teamMultisig.signers.length,
);

/// How the indexer records that [proposal] was created in the transaction
/// [_hash].
MultisigProposalCreatedEvent _created(MultisigProposal proposal) => MultisigProposalCreatedEvent(
  id: 'created-event',
  proposerId: proposal.proposer,
  multisigAddress: proposal.multisigAddress,
  recipient: proposal.recipient,
  amount: proposal.amount,
  palletFee: BigInt.zero,
  deposit: proposal.deposit,
  timestamp: _when,
  blockNumber: 10,
  blockHash: '0xblock',
  proposal: proposal,
  extrinsicHash: _hash,
);

Future<void> _clickSelectsTheAccount(WidgetTester tester) async {
  final notifications = FakeNotificationPlugin();
  final window = recordWindowRequests(tester);
  final container = await _openWallet(tester, notifications);

  notifications.click(_about(savingsAccount.accountId));
  await tester.pumpAndSettle();

  expect(window, ['bringToFront']);
  expect(_activeAccountId(container), savingsAccount.accountId);
}

void main() {
  testOnMac(
    'clicking a notification brings the window forward and selects the account it was about',
    _clickSelectsTheAccount,
  );

  testOnWindowsAndLinux(
    'clicking a notification brings the window forward and selects the account it was about',
    _clickSelectsTheAccount,
  );

  testOnMac('a click about an account that is gone since only brings the window forward', (tester) async {
    final notifications = FakeNotificationPlugin();
    final window = recordWindowRequests(tester);
    final container = await _openWallet(tester, notifications);

    notifications.click(_about('qzGone'));
    await tester.pumpAndSettle();

    expect(window, ['bringToFront']);
    expect(_activeAccountId(container), mainAccount.accountId);
  });

  testOnMac('a click that launched the app opens the account it was about', (tester) async {
    final notifications = FakeNotificationPlugin(launchedBy: _about(savingsAccount.accountId));
    final window = recordWindowRequests(tester);
    final container = await _openWallet(tester, notifications);

    expect(window, ['bringToFront']);
    expect(_activeAccountId(container), savingsAccount.accountId);
  });

  testOnMac("a click that launched the app waits for the wallet's accounts to load", (tester) async {
    final accounts = Completer<List<Account>>();
    final notifications = FakeNotificationPlugin(launchedBy: _about(savingsAccount.accountId));
    final container = await _openWallet(tester, notifications, loadAccounts: () => accounts.future, settle: false);
    await tester.pump(const Duration(milliseconds: 100));

    accounts.complete(const [mainAccount, savingsAccount]);
    await tester.pumpAndSettle();

    expect(_activeAccountId(container), savingsAccount.accountId);
  });

  group('a click opens what the notification was about', () {
    testOnMac('a transfer in the open account', (tester) async {
      final row = _transfer();
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(
        tester,
        notifications,
        chain: FakeSendChain()
          ..historyPages = [
            [row],
          ],
      );

      notifications.click(_aboutTransaction(mainAccount.accountId));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), mainAccount.accountId);
      expect(_opened(container), OpenedTransaction(row));
    });

    testOnMac('a transfer in another account, once that account is showing', (tester) async {
      final row = _transfer();
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(
        tester,
        notifications,
        chain: FakeSendChain()
          ..historyPages = [
            [row],
          ],
      );

      notifications.click(_aboutTransaction(savingsAccount.accountId));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), savingsAccount.accountId);
      expect(_opened(container), OpenedTransaction(row));
    });

    testOnMac('from Mining Rewards, back on the account', (tester) async {
      final row = _transfer();
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(
        tester,
        notifications,
        chain: FakeSendChain()
          ..historyPages = [
            [row],
          ],
      );
      await container.read(sidebarSelectionProvider.notifier).select(SidebarSelection.miningRewards);
      await tester.pumpAndSettle();

      notifications.click(_aboutTransaction(mainAccount.accountId));
      await tester.pumpAndSettle();

      expect(container.read(sidebarSelectionProvider), SidebarSelection.account);
      expect(_opened(container), OpenedTransaction(row));
    });

    testOnMac('after launching the app, once the accounts and the activity have loaded', (tester) async {
      final row = _transfer();
      final accounts = Completer<List<Account>>();
      final history = Completer<void>();
      final notifications = FakeNotificationPlugin(launchedBy: _aboutTransaction(savingsAccount.accountId));
      final container = await _openWallet(
        tester,
        notifications,
        loadAccounts: () => accounts.future,
        settle: false,
        chain: FakeSendChain()
          ..holdHistory = history
          ..historyPages = [
            [row],
          ],
      );
      await tester.pump(const Duration(milliseconds: 100));

      accounts.complete(const [mainAccount, savingsAccount]);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_activeAccountId(container), savingsAccount.accountId);
      expect(container.read(openedActivityProvider), isNull);

      history.complete();
      await tester.pumpAndSettle();

      expect(_opened(container), OpenedTransaction(row));
    });

    testOnMac('a created proposal, from Open Proposals of its multisig', (tester) async {
      final proposal = _proposal();
      final notifications = FakeNotificationPlugin();
      final chain = FakeSendChain()
        ..openProposals = [proposal]
        ..indexedProposals[_hash] = _created(proposal);
      final container = await _openWallet(tester, notifications, chain: chain, multisigs: [teamMultisig]);

      notifications.click(_aboutTransaction(teamMultisig.accountId));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), teamMultisig.accountId);
      expect(_opened(container), OpenedProposal(proposal));
    });

    for (final status in [MultisigProposalStatus.executed, MultisigProposalStatus.cancelled]) {
      testOnMac('a proposal since ${status.name}, from past activity', (tester) async {
        final proposal = _proposal(status: status);
        final notifications = FakeNotificationPlugin();
        final chain = FakeSendChain()
          ..pastProposals = [proposal]
          ..indexedProposals[_hash] = _created(proposal);
        final container = await _openWallet(tester, notifications, chain: chain, multisigs: [teamMultisig]);

        notifications.click(_aboutTransaction(teamMultisig.accountId));
        await tester.pumpAndSettle();

        expect(_activeAccountId(container), teamMultisig.accountId);
        expect(_opened(container), OpenedProposal(proposal));
      });
    }

    testOnMac('a "not confirmed" send that landed later', (tester) async {
      final row = _transfer();
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(
        tester,
        notifications,
        chain: FakeSendChain()
          ..historyPages = [
            [row],
          ],
      );
      final sends = container.read(pendingTransactionsProvider.notifier);
      withClock(Clock.fixed(_when), () {
        sends.add(
          PendingTransactionEvent(
            tempId: 'tx-1',
            from: mainAccount.accountId,
            to: 'qzBob',
            amount: oneToken,
            fee: BigInt.zero,
            timestamp: _when,
          ),
        );
        sends.updateState('tx-1', TransactionState.pending, extrinsicHash: _hash);
      });
      withClock(
        Clock.fixed(_when.add(PendingTransactionPollingService.timeout + const Duration(seconds: 5))),
        () => sends.remove('tx-1'),
      );
      await tester.pumpAndSettle();
      expect(notifications.shown.single.title, 'Send not confirmed');

      notifications.click(notifications.shown.single.payload);
      await tester.pumpAndSettle();

      expect(_opened(container), OpenedTransaction(row));
    });
  });

  group('what cannot be opened leaves the account showing, and nothing fails', () {
    testOnMac('a send that never landed', (tester) async {
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(
        tester,
        notifications,
        chain: FakeSendChain()
          ..historyPages = [
            [_transfer(hash: '0xother')],
          ],
      );

      notifications.click(_aboutTransaction(savingsAccount.accountId));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), savingsAccount.accountId);
      expect(container.read(openedActivityProvider), isNull);
      expect(tester.takeException(), isNull);
    });

    testOnMac('a transaction older than the loaded activity: no further page is read for it', (tester) async {
      final chain = FakeSendChain()
        ..historyPages = [
          // More than the panel shows, so it asks for no second page itself.
          [for (var i = 0; i < 60; i++) _transfer(hash: '0xnewer$i', id: 'newer-$i')],
          [_transfer(id: 'older')],
        ];
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(tester, notifications, chain: chain);
      expect(chain.historyReads, [0]);

      notifications.click(_aboutTransaction(mainAccount.accountId));
      await tester.pumpAndSettle();

      expect(container.read(openedActivityProvider), isNull);
      expect(chain.historyReads, isNot(contains(1)));
    });

    testOnMac('activity that fails to load', (tester) async {
      final chain = FakeSendChain();
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(tester, notifications, chain: chain);
      chain.historyError = StateError('the indexer is down');

      notifications.click(_aboutTransaction(savingsAccount.accountId));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), savingsAccount.accountId);
      expect(container.read(openedActivityProvider), isNull);
      expect(tester.takeException(), isNull);
    });

    testOnMac('a proposal lookup that fails, which is reported', (tester) async {
      recordWindowRequests(tester);
      final telemetry = _RecordingTelemetry();
      final chain = FakeSendChain()
        ..openProposals = [_proposal()]
        ..proposalLookupError = StateError('the indexer is down');
      final notifications = FakeNotificationPlugin();
      // Without the window: the app binds its own telemetry.
      final container = ProviderContainer(
        overrides: [
          ...shellOverrides(
            accounts: const [mainAccount, savingsAccount],
            chain: chain,
            settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount), multisigs: [teamMultisig]),
          ),
          ...liveDataOverrides(),
          notificationPluginProvider.overrideWithValue(notifications),
          telemetryProvider.overrideWithValue(telemetry),
        ],
      );
      addTearDown(container.dispose);
      await container.read(desktopLocalNotificationsProvider.notifier).start();

      notifications.click(_aboutTransaction(teamMultisig.accountId));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), teamMultisig.accountId);
      expect(container.read(openedActivityProvider), isNull);
      expect(telemetry.errors, ['desktop_notification_proposal_unread']);
    });

    testOnMac('an older notification, which names only the account, still opens the account', (tester) async {
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(
        tester,
        notifications,
        chain: FakeSendChain()
          ..historyPages = [
            [_transfer()],
          ],
      );

      notifications.click(_about(savingsAccount.accountId));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), savingsAccount.accountId);
      expect(container.read(openedActivityProvider), isNull);
    });
  });

  group('a click stays out of the way', () {
    for (final (name, account) in [('the open account', mainAccount), ('another account', savingsAccount)]) {
      testOnMac('with a sheet open, about $name, only the window comes forward', (tester) async {
        final notifications = FakeNotificationPlugin();
        final window = recordWindowRequests(tester);
        final container = await _openWallet(
          tester,
          notifications,
          chain: FakeSendChain()
            ..historyPages = [
              [_transfer()],
            ],
        );
        await container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
        await tester.pumpAndSettle();

        notifications.click(_aboutTransaction(account.accountId));
        await tester.pumpAndSettle();

        expect(window, ['bringToFront']);
        expect(_activeAccountId(container), mainAccount.accountId);
        expect(container.read(openedActivityProvider), isNull);
      });
    }

    testOnMac('picking another account while it loads: the click does not pull back', (tester) async {
      final history = Completer<void>();
      final chain = FakeSendChain()
        ..historyPages = [
          [_transfer()],
        ];
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(tester, notifications, chain: chain);
      chain.holdHistory = history;

      notifications.click(_aboutTransaction(savingsAccount.accountId));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_activeAccountId(container), savingsAccount.accountId);

      await container.read(sidebarSelectionProvider.notifier).showAccount(const RegularAccount(mainAccount));
      history.complete();
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), mainAccount.accountId);
      expect(container.read(openedActivityProvider), isNull);
    });

    testOnMac('going to Mining Rewards while it loads: the click does not pull back', (tester) async {
      final history = Completer<void>();
      final chain = FakeSendChain()
        ..historyPages = [
          [_transfer()],
        ];
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(tester, notifications, chain: chain);
      chain.holdHistory = history;

      notifications.click(_aboutTransaction(savingsAccount.accountId));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_activeAccountId(container), savingsAccount.accountId);

      await container.read(sidebarSelectionProvider.notifier).select(SidebarSelection.miningRewards);
      history.complete();
      await tester.pumpAndSettle();

      expect(container.read(sidebarSelectionProvider), SidebarSelection.miningRewards);
      expect(container.read(openedActivityProvider), isNull);
    });

    testOnMac('a second click on the same account drops what the first was about', (tester) async {
      final history = Completer<void>();
      final chain = FakeSendChain()
        ..historyPages = [
          [_transfer()],
        ];
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(tester, notifications, chain: chain);
      chain.holdHistory = history;

      notifications.click(_aboutTransaction(savingsAccount.accountId));
      await tester.pump(const Duration(milliseconds: 100));
      notifications.click(_aboutTransaction(savingsAccount.accountId, hash: '0xnotListed'));
      await tester.pump(const Duration(milliseconds: 100));
      history.complete();
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), savingsAccount.accountId);
      expect(container.read(openedActivityProvider), isNull);
    });

    testOnMac('a proposal waits for the open proposals as well as the activity', (tester) async {
      final proposal = _proposal();
      final held = Completer<void>();
      final chain = FakeSendChain()
        ..holdOpenProposals = held
        ..openProposals = [proposal]
        ..indexedProposals[_hash] = _created(proposal);
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(tester, notifications, chain: chain, multisigs: [teamMultisig]);

      notifications.click(_aboutTransaction(teamMultisig.accountId));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_activeAccountId(container), teamMultisig.accountId);
      expect(container.read(activityViewProvider).hasValue, isTrue);
      expect(container.read(openedActivityProvider), isNull);

      held.complete();
      await tester.pumpAndSettle();

      expect(_opened(container), OpenedProposal(proposal));
    });

    testOnMac('a click during a reload waits for the new rows', (tester) async {
      final row = _transfer();
      final chain = FakeSendChain()
        ..historyPages = [
          [_transfer(hash: '0xolder', id: 'older')],
        ];
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(tester, notifications, chain: chain);
      final history = Completer<void>();
      chain
        ..holdHistory = history
        ..historyPages = [
          [row],
        ];
      final params = activeAccountFilteredParams(container.read(activeAccountProvider).value, TransactionFilter.all)!;
      unawaited(container.read(filteredPaginationControllerProviderFamily(params).notifier).loadingRefresh());
      await tester.pump();
      expect(container.read(activityViewProvider).value?.isReloading, isTrue);

      notifications.click(_aboutTransaction(mainAccount.accountId));
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(openedActivityProvider), isNull);

      history.complete();
      await tester.pumpAndSettle();

      expect(_opened(container), OpenedTransaction(row));
    });

    testOnMac('a second click replaces a first one still waiting', (tester) async {
      final history = Completer<void>();
      final second = _transfer(hash: '0xsecond', id: 'second');
      final chain = FakeSendChain()
        ..historyPages = [
          [_transfer(), second],
        ];
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(tester, notifications, chain: chain);
      chain.holdHistory = history;

      notifications.click(_aboutTransaction(savingsAccount.accountId));
      await tester.pump(const Duration(milliseconds: 100));
      notifications.click(_aboutTransaction(mainAccount.accountId, hash: '0xsecond'));
      await tester.pump(const Duration(milliseconds: 100));
      history.complete();
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), mainAccount.accountId);
      expect(_opened(container), OpenedTransaction(second));
    });
  });
}
