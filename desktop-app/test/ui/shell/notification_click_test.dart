import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';
import 'package:quantus_desktop_wallet/services/own_activity_notifications.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_account_transactions_provider.dart';
import 'package:wallet_core/providers/encrypted_send_provider.dart';
import 'package:wallet_core/providers/filtered_all_transactions_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
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
/// loaded by [loadAccounts] when given, following [swaps], with 1Click as
/// [oneClick] answers.
Future<ProviderContainer> _openWallet(
  WidgetTester tester,
  FakeNotificationPlugin notifications, {
  Future<List<Account>> Function()? loadAccounts,
  bool settle = true,
  FakeSendChain? chain,
  List<MultisigAccount> multisigs = const [],
  List<Account> accounts = const [mainAccount, savingsAccount],
  Account active = mainAccount,
  List<ActiveSwap> swaps = const [],
  FakeSwapService? oneClick,
  List<Override> extra = const [],
}) async {
  await pumpShell(
    tester,
    notifications: notifications,
    settle: settle,
    overrides: [
      ...shellOverrides(
        accounts: accounts,
        loadAccounts: loadAccounts,
        chain: chain,
        settings: FakeSettingsService(activeAccount: RegularAccount(active), multisigs: multisigs)..activeSwaps = swaps,
        swaps: oneClick,
      ),
      ...extra,
    ],
  );
  return ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
}

/// What a notification about [accountId] carries.
String _about(String accountId) => jsonEncode({'accountId': accountId});

/// What a notification about the transaction [hash] in [accountId] carries.
String _aboutTransaction(String accountId, {String hash = _hash}) =>
    jsonEncode({'accountId': accountId, 'extrinsicHash': hash});

/// What a notification about the proposal [proposalId] of [accountId]
/// carries, with the transaction that created it when [hash] is given.
String _aboutProposal(String accountId, String proposalId, {String? hash}) =>
    jsonEncode({'accountId': accountId, 'extrinsicHash': ?hash, 'proposalId': proposalId});

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

MultisigProposal _proposal({MultisigProposalStatus status = MultisigProposalStatus.active, int id = 1}) =>
    MultisigProposal(
      entityId: 'proposal-$id',
      id: id,
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

  for (final refused in [false, true]) {
    testOnMac('a reset drops a click still waiting for the accounts${refused ? ', even if the system refuses' : ''}', (
      tester,
    ) async {
      final accounts = Completer<List<Account>>();
      final notifications = FakeNotificationPlugin(launchedBy: _about(savingsAccount.accountId));
      if (refused) notifications.cancelAllError = StateError('refused');
      final container = await _openWallet(tester, notifications, loadAccounts: () => accounts.future, settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      await container
          .read(desktopLocalNotificationsProvider.notifier)
          .cancelAll()
          .catchError((Object _) {}, test: (_) => refused);
      accounts.complete(const [mainAccount, savingsAccount]);
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), mainAccount.accountId);
    });
  }

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

    testOnMac('a transfer a multisig received: its transaction created no proposal', (tester) async {
      final row = TransferEvent(
        id: 'received',
        from: 'qzAlice',
        to: teamMultisig.accountId,
        amount: oneToken,
        timestamp: _when,
        fee: BigInt.zero,
        extrinsicHash: _hash,
        blockNumber: 10,
        blockHash: '0xblock',
      );
      final notifications = FakeNotificationPlugin();
      final chain = FakeSendChain()
        ..historyPages = [
          [row],
        ];
      final container = await _openWallet(tester, notifications, chain: chain, multisigs: [teamMultisig]);

      notifications.click(_aboutTransaction(teamMultisig.accountId));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), teamMultisig.accountId);
      expect(_opened(container), OpenedTransaction(row));
    });

    testOnMac('a transfer the open account received since its activity was last read: it is read again', (
      tester,
    ) async {
      final row = _transfer();
      final chain = FakeSendChain()
        ..historyPages = [
          [_transfer(hash: '0xolder', id: 'older')],
        ];
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(tester, notifications, chain: chain);
      expect(chain.historyReads, [0]);
      chain.historyPages = [
        [row, _transfer(hash: '0xolder', id: 'older')],
      ];

      notifications.click(_aboutTransaction(mainAccount.accountId));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), mainAccount.accountId);
      expect(_opened(container), OpenedTransaction(row));
      expect(chain.historyReads, [0, 0], reason: 'read again once, and only its first page');
    });

    testOnMac('a transfer the open multisig received since its activity was last read: it is read again', (
      tester,
    ) async {
      final row = TransferEvent(
        id: 'received',
        from: 'qzAlice',
        to: teamMultisig.accountId,
        amount: oneToken,
        timestamp: _when,
        fee: BigInt.zero,
        extrinsicHash: _hash,
        blockNumber: 10,
        blockHash: '0xblock',
      );
      final notifications = FakeNotificationPlugin();
      final chain = FakeSendChain();
      final container = await _openWallet(tester, notifications, chain: chain, multisigs: [teamMultisig]);
      notifications.click(_about(teamMultisig.accountId));
      await tester.pumpAndSettle();
      expect(_activeAccountId(container), teamMultisig.accountId);
      expect(container.read(activityViewProvider).value?.settled, isEmpty);
      chain.historyPages = [
        [row],
      ];

      notifications.click(_aboutTransaction(teamMultisig.accountId));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), teamMultisig.accountId);
      expect(_opened(container), OpenedTransaction(row));
    });

    for (final multisig in [false, true]) {
      final who = multisig ? 'multisig' : 'account';
      testOnMac('a transfer the open $who received while an older page of its activity loads: it is read again', (
        tester,
      ) async {
        final accountId = multisig ? teamMultisig.accountId : mainAccount.accountId;
        final row = TransferEvent(
          id: 'received',
          from: 'qzAlice',
          to: accountId,
          amount: oneToken,
          timestamp: _when,
          fee: BigInt.zero,
          extrinsicHash: _hash,
          blockNumber: 10,
          blockHash: '0xblock',
        );
        final older = [_transfer(hash: '0xolder', id: 'older')];
        final oldest = [_transfer(hash: '0xoldest', id: 'oldest')];
        final notifications = FakeNotificationPlugin();
        // The list asks for its next page by itself while it does not fill
        // the panel: that read is held.
        final page = Completer<void>();
        final chain = FakeSendChain()
          ..historyPages = [older, oldest]
          ..holdHistoryPages[1] = page;
        final container = await _openWallet(
          tester,
          notifications,
          chain: chain,
          multisigs: multisig ? [teamMultisig] : const [],
        );
        if (multisig) {
          notifications.click(_about(teamMultisig.accountId));
          await tester.pumpAndSettle();
        }
        expect(_activeAccountId(container), accountId);
        expect(chain.historyReads.sublist(chain.historyReads.length - 2), [0, 1], reason: 'the older page is loading');
        chain.historyReads.clear();
        chain.historyPages = [
          [row, ...older],
          oldest,
        ];

        notifications.click(_aboutTransaction(accountId));
        await tester.pump(const Duration(milliseconds: 100));
        page.complete();
        await tester.pumpAndSettle();

        expect(_opened(container), OpenedTransaction(row));
        // Then the list, short again, asks for its next page by itself.
        expect(chain.historyReads.first, 0, reason: 'the first page is read once the older one is in');
      });
    }

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

    testOnMac('a proposal created since the open multisig\'s lists were read: they are read again', (tester) async {
      final proposal = _proposal();
      final notifications = FakeNotificationPlugin();
      final chain = FakeSendChain();
      final container = await _openWallet(tester, notifications, chain: chain, multisigs: [teamMultisig]);
      notifications.click(_about(teamMultisig.accountId));
      await tester.pumpAndSettle();
      expect(_activeAccountId(container), teamMultisig.accountId);
      expect(container.read(openProposalsViewProvider)?.value?.open, isEmpty);
      chain
        ..openProposals = [proposal]
        ..indexedProposals[_hash] = _created(proposal);

      notifications.click(_aboutTransaction(teamMultisig.accountId));
      await tester.pumpAndSettle();

      expect(_opened(container), OpenedProposal(proposal));
    });

    testOnMac('a proposal executed since the open multisig\'s lists were read opens as it is now', (tester) async {
      final notifications = FakeNotificationPlugin();
      final chain = FakeSendChain()
        ..openProposals = [_proposal()]
        ..indexedProposals[_hash] = _created(_proposal());
      final container = await _openWallet(tester, notifications, chain: chain, multisigs: [teamMultisig]);
      notifications.click(_about(teamMultisig.accountId));
      await tester.pumpAndSettle();
      expect(container.read(openProposalsViewProvider)?.value?.open, hasLength(1));
      chain
        ..openProposals = const []
        ..pastProposals = [_proposal(status: MultisigProposalStatus.executed)];

      notifications.click(_aboutTransaction(teamMultisig.accountId));
      await tester.pumpAndSettle();

      final opened = _opened(container);
      expect(opened, isA<OpenedProposal>());
      expect((opened! as OpenedProposal).proposal.status, MultisigProposalStatus.executed);
    });

    testOnMac('two proposals created in one transaction: each notification opens its own', (tester) async {
      final first = _proposal();
      final second = _proposal(id: 2);
      final notifications = FakeNotificationPlugin();
      final chain = FakeSendChain()
        ..openProposals = [first, second]
        // Asked by the transaction alone, the indexer answers with the first.
        ..indexedProposals[_hash] = _created(first);
      final container = await _openWallet(tester, notifications, chain: chain, multisigs: [teamMultisig]);

      notifications.click(_aboutProposal(teamMultisig.accountId, second.entityId, hash: _hash));
      await tester.pumpAndSettle();
      expect(_opened(container), OpenedProposal(second));

      notifications.click(_aboutProposal(teamMultisig.accountId, first.entityId, hash: _hash));
      await tester.pumpAndSettle();
      expect(_opened(container), OpenedProposal(first));
    });

    testOnMac('a proposal named by the notification is not looked up by its transaction', (tester) async {
      final proposal = _proposal();
      final notifications = FakeNotificationPlugin();
      final chain = FakeSendChain()
        ..openProposals = [proposal]
        ..proposalLookupError = StateError('the indexer is down');
      final container = await _openWallet(tester, notifications, chain: chain, multisigs: [teamMultisig]);

      notifications.click(_aboutProposal(teamMultisig.accountId, proposal.entityId));
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

  group('an Encrypted send', () {
    final landed = WormholeTransferEvent(
      id: '0xlast',
      from: encryptedAccount.accountId,
      to: 'qzBob',
      amount: oneToken,
      timestamp: _when,
      fee: BigInt.zero,
      extrinsicHash: '0xlast',
      blockNumber: 10,
    );

    /// The history as the account's last read of its state found it.
    Override historyOf(List<TransactionEvent> rows) => encryptedHistoryProvider.overrideWith((ref, walletIndex) {
      ref.watch(encryptedStateProvider(walletIndex));
      return AsyncValue.data(List.of(rows));
    });

    /// The send, of two batches, is handed over and both land.
    Future<void> sendLands(WidgetTester tester, ProviderContainer container, FakeSendChain chain) async {
      container
          .read(ownActivityNotificationsProvider)
          .onEncryptedSendEnded(
            account: encryptedAccount,
            amount: oneToken,
            send: EncryptedSendState(phase: EncryptedSendPhase.succeeded, txHashes: const ['0xfirst', '0xlast']),
          );
      chain.indexedTransfers['0xfirst'] = _transfer(hash: '0xfirst', id: 'first');
      chain.indexedTransfers['0xlast'] = _transfer(hash: '0xlast', id: 'last');
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    }

    testOnMac('opens from its notification, its history read again once the chain has it', (tester) async {
      final rows = <TransactionEvent>[];
      final chain = FakeSendChain();
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(
        tester,
        notifications,
        chain: chain,
        accounts: const [mainAccount, encryptedAccount],
        active: encryptedAccount,
        extra: [historyOf(rows)],
      );
      expect(container.read(activityViewProvider).value?.settled, isEmpty);

      rows.add(landed);
      await sendLands(tester, container, chain);
      notifications.click(notifications.shown.single.payload);
      await tester.pumpAndSettle();

      expect(_opened(container), OpenedTransaction(landed));
    });

    testOnMac('whose history has not caught up still opens the account, and nothing fails', (tester) async {
      final chain = FakeSendChain();
      final notifications = FakeNotificationPlugin();
      final container = await _openWallet(
        tester,
        notifications,
        chain: chain,
        accounts: const [mainAccount, encryptedAccount],
        extra: [historyOf(const [])],
      );

      await sendLands(tester, container, chain);
      notifications.click(notifications.shown.single.payload);
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), encryptedAccount.accountId);
      expect(container.read(openedActivityProvider), isNull);
      expect(tester.takeException(), isNull);
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

    testOnMac('proposal lists that cannot be read again, which is reported', (tester) async {
      recordWindowRequests(tester);
      final telemetry = _RecordingTelemetry();
      final chain = FakeSendChain()
        ..openProposals = [_proposal()]
        ..indexedProposals[_hash] = _created(_proposal());
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
      // Watched, as the window's panels watch them: the lists stay read.
      container.listen(activityViewProvider, (_, _) {});
      container.listen(openProposalsViewProvider, (_, _) {});
      notifications.click(_about(teamMultisig.accountId));
      await tester.pumpAndSettle();
      expect(_activeAccountId(container), teamMultisig.accountId);
      expect(container.read(openProposalsViewProvider)?.value?.open, hasLength(1));
      chain.pastProposalsError = StateError('the indexer is down');

      notifications.click(_aboutTransaction(teamMultisig.accountId));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), teamMultisig.accountId);
      expect(container.read(openedActivityProvider), isNull, reason: 'not the proposal as it was before');
      expect(telemetry.errors, ['desktop_notification_proposals_unread']);
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

    testOnMac('picking another account while the activity is read again: the click does not pull back', (tester) async {
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
          [_transfer()],
        ];

      notifications.click(_aboutTransaction(mainAccount.accountId));
      await tester.pump(const Duration(milliseconds: 100));
      expect(chain.historyReads, [0, 0], reason: 'the activity is being read again');

      await container.read(sidebarSelectionProvider.notifier).showAccount(const RegularAccount(savingsAccount));
      history.complete();
      await tester.pumpAndSettle();
      await container.read(sidebarSelectionProvider.notifier).showAccount(const RegularAccount(mainAccount));
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

    group('during a proposal lookup', () {
      /// Clicks a notification about a proposal of Team whose lookup waits
      /// for the completer handed back.
      Future<({ProviderContainer container, Completer<void> lookup, MultisigProposal proposal})> clicked(
        WidgetTester tester,
      ) async {
        final proposal = _proposal();
        final lookup = Completer<void>();
        final chain = FakeSendChain()
          ..openProposals = [proposal]
          ..indexedProposals[_hash] = _created(proposal)
          ..holdProposalLookup = lookup;
        final notifications = FakeNotificationPlugin();
        final container = await _openWallet(tester, notifications, chain: chain, multisigs: [teamMultisig]);
        notifications.click(_aboutTransaction(teamMultisig.accountId));
        await tester.pumpAndSettle();
        expect(_activeAccountId(container), teamMultisig.accountId);
        return (container: container, lookup: lookup, proposal: proposal);
      }

      /// Back on Team, the lookup answers: what the click did is what is open.
      Future<void> lookupAnswersWithNothingOpened(
        WidgetTester tester,
        ProviderContainer container,
        Completer<void> lookup,
      ) async {
        expect(_activeAccountId(container), teamMultisig.accountId);
        expect(container.read(sidebarSelectionProvider), SidebarSelection.account);
        lookup.complete();
        await tester.pumpAndSettle();
        expect(container.read(openedActivityProvider), isNull);
      }

      testOnMac('a person who stays still gets the proposal, however slow the answer', (tester) async {
        final (:container, :lookup, :proposal) = await clicked(tester);

        lookup.complete();
        await tester.pumpAndSettle();

        expect(_opened(container), OpenedProposal(proposal));
      });

      testOnMac('a reset drops the click', (tester) async {
        final (:container, :lookup, proposal: _) = await clicked(tester);

        await container.read(desktopLocalNotificationsProvider.notifier).cancelAll();

        await lookupAnswersWithNothingOpened(tester, container, lookup);
      });

      testOnMac('going to Mining Rewards and back drops the click', (tester) async {
        final (:container, :lookup, proposal: _) = await clicked(tester);
        final selection = container.read(sidebarSelectionProvider.notifier);

        await selection.select(SidebarSelection.miningRewards);
        await tester.pumpAndSettle();
        await selection.select(SidebarSelection.account);
        await tester.pumpAndSettle();

        await lookupAnswersWithNothingOpened(tester, container, lookup);
      });

      testOnMac('going to another account and back drops the click', (tester) async {
        final (:container, :lookup, proposal: _) = await clicked(tester);
        final selection = container.read(sidebarSelectionProvider.notifier);

        await selection.showAccount(const RegularAccount(mainAccount));
        await tester.pumpAndSettle();
        await selection.showAccount(MultisigDisplayAccount(teamMultisig));
        await tester.pumpAndSettle();

        await lookupAnswersWithNothingOpened(tester, container, lookup);
      });

      testOnMac('opening a sheet and closing it drops the click', (tester) async {
        final (:container, :lookup, proposal: _) = await clicked(tester);

        await container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(ShellSheetView))).pop();
        await tester.pumpAndSettle();
        expect(container.read(shellSheetProvider), isNull);

        await lookupAnswersWithNothingOpened(tester, container, lookup);
      });
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

  group('a click on a swap\'s notification', () {
    /// What a notification about the swap [swapId] from [accountId] carries.
    String aboutSwap(String accountId, String swapId) => jsonEncode({'accountId': accountId, 'swapId': swapId});

    testOnMac('shows the account the swap is from, and opens the swap', (tester) async {
      final notifications = FakeNotificationPlugin();
      final swap = fakeActiveSwap(account: savingsAccount);
      final container = await _openWallet(tester, notifications, swaps: [swap]);

      notifications.click(aboutSwap(savingsAccount.accountId, swap.id));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), savingsAccount.accountId);
      expect(_opened(container), OpenedSwap(swap.id));
    });

    testOnMac('shows only its account once the swap is no longer followed', (tester) async {
      final notifications = FakeNotificationPlugin();
      final swap = fakeActiveSwap(account: savingsAccount);
      final container = await _openWallet(tester, notifications);

      notifications.click(aboutSwap(savingsAccount.accountId, swap.id));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), savingsAccount.accountId);
      expect(_opened(container), isNull);
    });

    testOnMac('opens a swap whose account the wallet no longer holds under the account in front', (tester) async {
      final notifications = FakeNotificationPlugin();
      final swap = fakeActiveSwap(account: tradingAccount);
      final container = await _openWallet(tester, notifications, swaps: [swap]);

      notifications.click(aboutSwap(tradingAccount.accountId, swap.id));
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), mainAccount.accountId);
      expect(_opened(container), OpenedSwap(swap.id));
    });

    testOnMac('opens the swap its own notification told the end of', (tester) async {
      final notifications = FakeNotificationPlugin();
      final oneClick = FakeSwapService();
      final swap = fakeActiveSwap(account: savingsAccount);
      final container = await _openWallet(tester, notifications, swaps: [swap], oneClick: oneClick);
      oneClick.status = (order) async => SwapOrder(quote: order.quote, status: SwapStatus.success);
      await tester.pump(SwapService.statusPollInterval);

      notifications.click(notifications.shown.single.payload);
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), savingsAccount.accountId);
      expect(_opened(container), OpenedSwap(swap.id));
    });
  });
}
