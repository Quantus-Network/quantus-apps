import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_skeleton.dart';
import 'package:quantus_desktop_wallet/ui/activity/in_progress_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_card.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/services/global_history_polling_service.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_account_transactions_provider.dart';
import 'package:wallet_core/providers/filtered_all_transactions_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));
final _now = DateTime.now();

TransferEvent _transfer(String id, {required String from, required String to, required Duration ago}) => TransferEvent(
  id: id,
  from: from,
  to: to,
  amount: oneToken * BigInt.from(5),
  timestamp: _now.subtract(ago),
  fee: FakeSendChain.usualFee,
  extrinsicHash: '0x$id',
  blockNumber: 1,
  blockHash: '0xblock',
);

TransferEvent _sent(String id, Duration ago) => _transfer(id, from: 'qzMain', to: 'qzBob', ago: ago);
TransferEvent _received(String id, Duration ago) => _transfer(id, from: 'qzBob', to: 'qzMain', ago: ago);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

/// Opens Main's wallet on the history the [chain] holds, with Main active
/// unless [active] says otherwise.
Future<void> _open(
  WidgetTester tester, {
  FakeSendChain? chain,
  FakeHistoryPollingManager? polling,
  DisplayAccount active = const RegularAccount(mainAccount),
  List<Override> extra = const [],
  bool settle = true,
  bool realPolling = false,
}) => pumpShell(
  tester,
  polling: polling,
  settle: settle,
  realPolling: realPolling,
  overrides: [
    ...shellOverrides(
      accounts: const [mainAccount, savingsAccount, encryptedAccount],
      settings: FakeSettingsService(activeAccount: active),
      balances: oneTokenEach,
      encryptedBalances: {0: oneToken},
      chain: chain,
    ),
    ...extra,
  ],
);

/// The rows of a panel, by their transactions' ids, top to bottom.
List<String> _rowsIn(WidgetTester tester, Type panel) => [
  for (final row in tester.widgetList<ActivityRowView>(
    find.descendant(of: find.byType(panel), matching: find.byType(ActivityRowView)),
  ))
    row.id,
];

void main() {
  testOnMac('settled activity is listed under its days, in capitals, newest first', (tester) async {
    final chain = FakeSendChain()
      ..historyPages = [
        [
          _received('today', const Duration(minutes: 5)),
          _sent('yesterday', const Duration(days: 1)),
          _received('older', const Duration(days: 9)),
        ],
      ];
    await _open(tester, chain: chain);

    expect(_rowsIn(tester, ActivityPanel), ['today', 'yesterday', 'older']);
    final headings = [_l10n.activityDateToday, _l10n.activityDateYesterday];
    for (final heading in headings) {
      expect(find.descendant(of: find.byType(ActivityPanel), matching: find.text(heading.toUpperCase())), findsOne);
    }
    expect(
      tester.getTopLeft(find.text('TODAY')).dy,
      lessThan(tester.getTopLeft(find.byType(ActivityRowView).first).dy),
    );
  });

  testOnMac('what is under way is in the In progress panel, in the phone\'s order, and not in Activity', (
    tester,
  ) async {
    final scheduled = ReversibleTransferEvent(
      id: 'scheduled',
      from: 'qzMain',
      to: 'qzBob',
      amount: oneToken,
      timestamp: _now,
      txId: '0xtxid',
      status: ReversibleTransferStatus.SCHEDULED,
      scheduledAt: _now.add(const Duration(hours: 23)),
      blockNumber: 1,
      blockHash: '0xblock',
    );
    final chain = FakeSendChain()
      ..scheduledTransfers = [scheduled]
      ..historyPages = [
        [_received('settled', const Duration(hours: 2))],
      ];
    await _open(tester, chain: chain);
    _container(tester)
        .read(pendingTransactionsProvider.notifier)
        .add(
          PendingTransactionEvent(
            tempId: 'sending',
            from: 'qzMain',
            to: 'qzBob',
            amount: oneToken,
            timestamp: _now,
            fee: null,
          ),
        );
    final proposing = PendingMultisigProposalEvent.create(
      msig: teamMultisig,
      proposerId: 'qzMain',
      recipient: 'qzBob',
      amount: oneToken,
      expiryBlock: 1300000,
      fee: BigInt.one,
      deposit: BigInt.one,
      palletFee: BigInt.one,
    );
    _container(tester).read(pendingMultisigProposalsProvider.notifier).add(proposing);
    await tester.pumpAndSettle();

    expect(_rowsIn(tester, InProgressPanel), [proposing.id, 'sending', 'scheduled']);
    expect(_rowsIn(tester, ActivityPanel), ['settled']);
    expect(
      find.descendant(of: find.byType(InProgressPanel), matching: find.text(_l10n.desktopActivityInProgress)),
      findsOne,
    );
  });

  testOnMac('with nothing under way there is no In progress panel', (tester) async {
    await _open(
      tester,
      chain: FakeSendChain()
        ..historyPages = [
          [_sent('settled', const Duration(hours: 2))],
        ],
    );

    expect(find.byType(InProgressPanel), findsNothing);
    expect(tester.getRect(find.byType(ActivityPanel)).top, tester.getRect(find.byType(BalanceCard)).bottom + Panel.gap);
  });

  testOnMac('a long In progress list stops at half the column and scrolls', (tester) async {
    final chain = FakeSendChain()
      ..scheduledTransfers = [
        for (var i = 0; i < 12; i++)
          ReversibleTransferEvent(
            id: 'scheduled-$i',
            from: 'qzMain',
            to: 'qzBob',
            amount: oneToken,
            timestamp: _now,
            txId: '0xtxid$i',
            status: ReversibleTransferStatus.SCHEDULED,
            scheduledAt: _now.add(Duration(hours: i + 1)),
            blockNumber: 1,
            blockHash: '0xblock',
          ),
      ];
    await _open(tester, chain: chain);

    final column = tester.getRect(find.byType(BalanceCard)).top;
    final footerTop = tester.getRect(find.byType(ActivityPanel)).bottom;
    expect(tester.getRect(find.byType(InProgressPanel)).height, lessThanOrEqualTo((footerTop - column) / 2));
    expect(find.descendant(of: find.byType(InProgressPanel), matching: find.byType(Scrollable)), findsOne);
  });

  testOnMac('with no activity at all it says there are no transactions yet', (tester) async {
    await _open(tester, chain: FakeSendChain());

    expect(find.descendant(of: find.byType(ActivityPanel), matching: find.text(_l10n.activityEmpty)), findsOne);
    expect(find.byType(ActivityRowView), findsNothing);
  });

  group('loading', () {
    testOnMac('a load that ends within 0.4 s shows no skeleton', (tester) async {
      final chain = FakeSendChain()
        ..holdHistory = Completer<void>()
        ..historyPages = [
          [_sent('settled', const Duration(hours: 2))],
        ];
      await _open(tester, chain: chain, settle: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ActivitySkeleton), findsNothing);

      chain.holdHistory!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ActivitySkeleton), findsNothing);
      expect(_rowsIn(tester, ActivityPanel), ['settled']);
    });

    testOnMac('a slower load shows the skeleton from 0.4 s, for at least 0.5 s, then the rows', (tester) async {
      final chain = FakeSendChain()
        ..holdHistory = Completer<void>()
        ..historyPages = [
          [_sent('settled', const Duration(hours: 2))],
        ];
      await _open(tester, chain: chain, settle: false);
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(ActivitySkeleton), findsOne);
      // The rows' shapes start where the rows will, under the header.
      expect(
        tester.getRect(find.byType(ActivitySkeleton)).top,
        moreOrLessEquals(tester.getRect(find.byType(ActivityPanel)).top + Panel.headerHeight + 1, epsilon: 1),
      );

      chain.holdHistory!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ActivitySkeleton), findsOne, reason: 'shown 0.15 s, so kept to 0.5 s');

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(ActivitySkeleton), findsNothing);
      expect(_rowsIn(tester, ActivityPanel), ['settled']);
    });

    testOnMac("a first load's skeleton fills the panel with days of rows, as real activity would", (tester) async {
      final chain = FakeSendChain()..holdHistory = Completer<void>();
      await _open(tester, chain: chain, settle: false);
      await tester.pump(const Duration(milliseconds: 450));

      var rows = 0;
      while (find.byKey(ActivitySkeleton.rowKey(rows)).evaluate().isNotEmpty) {
        rows++;
      }
      expect(rows, greaterThan(1));
      final last = tester.getRect(find.byKey(ActivitySkeleton.rowKey(rows - 1)));
      final panel = tester.getRect(find.byType(ActivityPanel));
      expect(last.bottom, lessThanOrEqualTo(panel.bottom));
      expect(last.bottom, greaterThan(panel.bottom - 1 - last.height), reason: 'within one row of the bottom');
      expect(find.byKey(ActivitySkeleton.headingKey(1)), findsOne, reason: 'more than one day');

      chain.holdHistory!.complete();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });

    testOnMac('the skeleton breathes, and holds still when the system asks for less motion', (tester) async {
      final chain = FakeSendChain()..holdHistory = Completer<void>();
      await _open(tester, chain: chain, settle: false);
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(ActivitySkeleton), findsOne);
      // pumpShell asks for less motion: a bone is the same a moment later.
      Color? bone() =>
          (tester
                      .widget<Container>(
                        find.descendant(of: find.byType(ActivitySkeleton), matching: find.byType(Container)).first,
                      )
                      .decoration
                  as BoxDecoration?)
              ?.color;
      final before = bone();
      await tester.pump(const Duration(milliseconds: 800));
      expect(bone(), before);

      chain.holdHistory!.complete();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });
  });

  testOnMac('scrolling near the end loads the next page, with skeleton rows meanwhile; the last loads no more', (
    tester,
  ) async {
    final chain = FakeSendChain()
      ..historyPages = [
        [for (var i = 0; i < 20; i++) _received('first-$i', Duration(hours: i + 1))],
        [_received('second', const Duration(days: 30))],
      ];
    await _open(tester, chain: chain);
    expect(chain.historyReads, [0]);
    chain.holdHistory = Completer<void>();

    await tester.drag(find.byType(ActivityPanel), const Offset(0, -3000));
    // The list springs back to its end, where the shapes of what is coming
    // show while it loads.
    await tester.pumpAndSettle();
    expect(chain.historyReads, [0, 1]);
    expect(find.byKey(ActivityPanel.loadingMoreKey), findsOne);

    chain.holdHistory!.complete();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ActivityPanel), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(_rowsIn(tester, ActivityPanel).last, 'second');
    expect(find.byKey(ActivityPanel.loadingMoreKey), findsNothing);
    expect(chain.historyReads, [0, 1]);
  });

  group('refreshing', () {
    testOnMac('↻ refreshes: a line runs under the header while it does, and the list stays', (tester) async {
      final polling = FakeHistoryPollingManager()..holdRefresh = Completer<void>();
      await _open(
        tester,
        polling: polling,
        chain: FakeSendChain()
          ..historyPages = [
            [_sent('settled', const Duration(hours: 2))],
          ],
      );

      await tester.tap(find.byKey(ActivityPanel.refreshKey));
      await tester.pump();
      expect(polling.calls, contains('manualRefresh'));
      expect(find.descendant(of: find.byType(ActivityPanel), matching: find.byKey(Panel.busyLineKey)), findsOne);
      expect(_rowsIn(tester, ActivityPanel), ['settled']);

      polling.holdRefresh!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(Panel.busyLineKey), findsNothing);
    });

    testOnMac('a refresh that fails stops the line all the same', (tester) async {
      final polling = FakeHistoryPollingManager()..refreshError = StateError('offline');
      await _open(tester, polling: polling, chain: FakeSendChain());

      await tester.tap(find.byKey(ActivityPanel.refreshKey));
      await tester.pumpAndSettle();

      expect(_container(tester).read(walletRefreshingProvider), isFalse);
      expect(find.byKey(Panel.busyLineKey), findsNothing);
    });
  });

  // The refreshes here run through the real polling, as the app's do: a
  // refresh asked for reloads an account's history from nothing.
  group('reloading', () {
    Finder busyLine() => find.descendant(of: find.byType(ActivityPanel), matching: find.byKey(Panel.busyLineKey));

    Future<void> refresh(WidgetTester tester) async {
      await tester.tap(find.byKey(ActivityPanel.refreshKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testOnMac('a refresh keeps the rows on screen with the line under the header, then shows the new ones', (
      tester,
    ) async {
      final chain = FakeSendChain()
        ..historyPages = [
          [_sent('old', const Duration(hours: 2))],
        ];
      await _open(tester, chain: chain, realPolling: true);
      chain
        ..holdHistory = Completer<void>()
        ..historyPages = [
          [_received('new', const Duration(minutes: 5)), _sent('old', const Duration(hours: 2))],
        ];

      await refresh(tester);

      expect(find.byType(ActivitySkeleton), findsNothing);
      expect(_rowsIn(tester, ActivityPanel), ['old']);
      expect(busyLine(), findsOne);

      chain.holdHistory!.complete();
      await tester.pumpAndSettle();
      expect(_rowsIn(tester, ActivityPanel), ['new', 'old']);
      expect(busyLine(), findsNothing);
    });

    testOnMac('a refresh leaves In progress where it is: nothing under it moves', (tester) async {
      final scheduled = ReversibleTransferEvent(
        id: 'scheduled',
        from: 'qzMain',
        to: 'qzBob',
        amount: oneToken,
        timestamp: _now,
        txId: '0xtxid',
        status: ReversibleTransferStatus.SCHEDULED,
        scheduledAt: _now.add(const Duration(hours: 23)),
        blockNumber: 1,
        blockHash: '0xblock',
      );
      final chain = FakeSendChain()
        ..scheduledTransfers = [scheduled]
        ..historyPages = [
          [_received('settled', const Duration(hours: 2))],
        ];
      await _open(tester, chain: chain, realPolling: true);
      final activityTop = tester.getRect(find.byType(ActivityPanel)).top;
      chain.holdHistory = Completer<void>();

      await refresh(tester);

      expect(_rowsIn(tester, InProgressPanel), ['scheduled']);
      expect(tester.getRect(find.byType(ActivityPanel)).top, activityTop);

      chain.holdHistory!.complete();
      await tester.pumpAndSettle();
    });

    testOnMac('an account shows the skeleton on its first load only', (tester) async {
      final chain = FakeSendChain()
        ..historyPages = [
          [_sent('settled', const Duration(hours: 2))],
        ];
      await _open(tester, chain: chain, realPolling: true);
      Future<void> show(String account) =>
          tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text(account)));

      chain.holdHistory = Completer<void>();
      await show('Savings');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(ActivitySkeleton), findsOne, reason: "Savings' first load");
      chain.holdHistory!.complete();
      await tester.pumpAndSettle();

      await show('Main');
      await tester.pumpAndSettle();
      chain.holdHistory = Completer<void>();
      await show('Savings');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ActivitySkeleton), findsNothing);
      expect(_rowsIn(tester, ActivityPanel), ['settled']);

      chain.holdHistory!.complete();
      await tester.pumpAndSettle();
    });

    testOnMac('a reload not asked for, as after an account is added, keeps the rows too, with the line', (
      tester,
    ) async {
      final chain = FakeSendChain()
        ..historyPages = [
          [_sent('settled', const Duration(hours: 2))],
        ];
      await _open(tester, chain: chain, realPolling: true);
      final container = _container(tester);
      final params = activeAccountFilteredParams(container.read(activeAccountProvider).value, TransactionFilter.all)!;
      chain.holdHistory = Completer<void>();

      // What the history does when the accounts change.
      unawaited(container.read(filteredPaginationControllerProviderFamily(params).notifier).loadingRefresh());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ActivitySkeleton), findsNothing);
      expect(_rowsIn(tester, ActivityPanel), ['settled']);
      expect(busyLine(), findsOne);

      chain.holdHistory!.complete();
      await tester.pumpAndSettle();
      expect(busyLine(), findsNothing);
    });

    testOnMac('the once-a-minute poll runs no line', (tester) async {
      final chain = FakeSendChain()
        ..historyPages = [
          [_sent('settled', const Duration(hours: 2))],
        ];
      await _open(tester, chain: chain, realPolling: true);
      final reads = chain.historyReads.length;
      chain.holdHistory = Completer<void>();

      await tester.pump(GlobalHistoryPollingService.pollInterval);
      await tester.pump();
      expect(chain.historyReads.length, greaterThan(reads), reason: 'the poll is reading');

      expect(busyLine(), findsNothing);
      expect(_rowsIn(tester, ActivityPanel), ['settled']);

      chain.holdHistory!.complete();
      await tester.pumpAndSettle();
    });

    testOnMac('a refresh that fails keeps the rows, with a note and Try Again; once one succeeds the note goes', (
      tester,
    ) async {
      final chain = FakeSendChain()
        ..historyPages = [
          [_sent('settled', const Duration(hours: 2))],
        ];
      await _open(tester, chain: chain, realPolling: true);
      chain.historyError = StateError('indexer down');

      await tester.tap(find.byKey(ActivityPanel.refreshKey));
      await tester.pumpAndSettle();

      expect(_rowsIn(tester, ActivityPanel), ['settled']);
      expect(find.text(_l10n.desktopActivityRefreshFailed), findsOne);
      expect(find.text(_l10n.desktopActivityLoadFailed), findsNothing);

      chain.historyError = null;
      await tester.tap(find.descendant(of: find.byType(ActivityPanel), matching: find.text(_l10n.commonTryAgain)));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.desktopActivityRefreshFailed), findsNothing);
      expect(_rowsIn(tester, ActivityPanel), ['settled']);
    });

    testOnMac('while kept rows show over a reload, no older page is asked for at the list\'s end', (tester) async {
      final chain = FakeSendChain()
        ..historyPages = [
          [for (var i = 0; i < 20; i++) _received('first-$i', Duration(hours: i + 1))],
          [_received('second', const Duration(days: 30))],
        ];
      await _open(tester, chain: chain, realPolling: true);
      expect(chain.historyReads, [0]);
      chain.holdHistory = Completer<void>();

      await refresh(tester);
      await tester.drag(find.byType(ActivityPanel), const Offset(0, -3000));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(chain.historyReads, [0, 0], reason: 'the refresh reads the first page again, and nothing more');

      chain.holdHistory!.complete();
      await tester.pumpAndSettle();
    });
  });

  testOnMac('a failed load says so, with the error, and Try Again refreshes', (tester) async {
    final polling = FakeHistoryPollingManager();
    await _open(tester, polling: polling, chain: FakeSendChain()..historyError = StateError('indexer down'));

    expect(find.text(_l10n.desktopActivityLoadFailed), findsOne);
    expect(find.text('Bad state: indexer down'), findsOne);

    await tester.tap(find.text(_l10n.commonTryAgain));
    await tester.pumpAndSettle();
    expect(polling.calls, contains('manualRefresh'));
  });

  testOnMac('the Encrypted account lists its private history in its words, with no notice, and loads no more', (
    tester,
  ) async {
    final privateReceipt = WormholeTransferEvent(
      id: 'private',
      from: 'qzBob',
      to: 'qzEncrypted',
      amount: oneToken,
      timestamp: _now.subtract(const Duration(hours: 3)),
      fee: BigInt.zero,
      extrinsicHash: '0xprivate',
      blockNumber: 1,
    );
    final chain = FakeSendChain();
    await _open(
      tester,
      chain: chain,
      active: const RegularAccount(encryptedAccount),
      extra: [
        encryptedHistoryProvider.overrideWith((ref, walletIndex) => AsyncValue.data([privateReceipt])),
      ],
    );

    expect(_rowsIn(tester, ActivityPanel), ['private']);
    expect(find.text(_l10n.activityTxPrivateReceived), findsOne);
    expect(find.text(_l10n.activitySenderEncrypted), findsOne);
    expect(find.byType(PrivateActivityNotice), findsNothing);
    expect(chain.historyReads, isEmpty);
  });

  testOnMac('a mining reward is received from "Mining reward"', (tester) async {
    await _open(
      tester,
      chain: FakeSendChain()
        ..historyPages = [
          [
            MinerRewardEvent(
              id: 'reward',
              miner: 'qzMain',
              reward: oneToken,
              timestamp: _now.subtract(const Duration(minutes: 12)),
              blockNumber: 1,
              blockHash: '0xreward',
            ),
          ],
        ],
    );

    expect(
      find.descendant(of: find.byType(ActivityPanel), matching: find.text(_l10n.activitySenderMiningReward)),
      findsOne,
    );
    expect(find.descendant(of: find.byType(ActivityPanel), matching: find.text(_l10n.activityTxFrom)), findsOne);
  });

  testOnMac('clicking a row opens it; switching account closes it', (tester) async {
    await _open(
      tester,
      chain: FakeSendChain()
        ..historyPages = [
          [_sent('settled', const Duration(hours: 2))],
        ],
    );

    await tester.tap(find.byType(ActivityRowView));
    await tester.pumpAndSettle();
    expect(_container(tester).read(openedActivityProvider), isA<OpenedTransaction>());
    expect(tester.widget<ActivityRowView>(find.byType(ActivityRowView)).isSelected, isTrue);

    await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Savings')));
    await tester.pumpAndSettle();
    expect(_container(tester).read(openedActivityProvider), isNull);
  });
}
