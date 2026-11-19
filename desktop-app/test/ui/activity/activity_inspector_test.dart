import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/services/share_service.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_inspector.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/activity/open_proposals_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/panel_resize_handle.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/models/filtered_transactions_params.dart';
import 'package:wallet_core/providers/active_account_transactions_provider.dart';
import 'package:wallet_core/providers/filtered_all_transactions_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));
final _now = DateTime.now();
const _bob = 'qzBob4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Finder _inPanel(Finder finder) => find.descendant(of: find.byType(ActivityInspector), matching: finder);

/// What is pressed, opened and shared, instead of the computer doing it.
class _Outside {
  final opened = <Uri>[];
  final shared = <String>[];

  List<Override> get overrides => [
    openExternalUrlProvider.overrideWithValue((url) async => opened.add(url)),
    shareTextProvider.overrideWithValue((text, {origin}) async => shared.add(text)),
  ];
}

Future<_Outside> _open(
  WidgetTester tester,
  FakeSendChain chain, {
  DisplayAccount active = const RegularAccount(mainAccount),
  List<MultisigAccount> multisigs = const [],
  List<Override> extra = const [],
  bool reduceMotion = true,
}) async {
  final outside = _Outside();
  await pumpShell(
    tester,
    reduceMotion: reduceMotion,
    overrides: [
      ...shellOverrides(
        accounts: const [mainAccount, savingsAccount, encryptedAccount],
        settings: FakeSettingsService(activeAccount: active, multisigs: multisigs),
        balances: oneTokenEach,
        encryptedBalances: {0: oneToken},
        chain: chain,
      ),
      ...outside.overrides,
      ...extra,
    ],
  );
  return outside;
}

TransferEvent _transfer(
  String id, {
  required String from,
  required String to,
  Duration ago = const Duration(days: 1),
}) => TransferEvent(
  id: id,
  from: from,
  to: to,
  amount: oneToken * BigInt.from(75),
  timestamp: _now.subtract(ago),
  fee: FakeSendChain.usualFee,
  extrinsicHash: '0x$id',
  blockNumber: 1,
  blockHash: '0xblock',
);

/// Opens the row of the transaction with [id].
Future<void> _openRow(WidgetTester tester, String id) async {
  await tester.tap(find.byWidgetPredicate((widget) => widget is ActivityRowView && widget.id == id));
  await tester.pumpAndSettle();
}

String _money(WidgetTester tester, BigInt amount) {
  final formatting = _container(tester).read(numberFormattingServiceProvider);
  return _l10n.commonAmountBalance(formatting.formatBalance(amount), AppConstants.tokenSymbol);
}

ToolbarAction _action(WidgetTester tester, String label) =>
    tester.widget<ToolbarAction>(_inPanel(find.byWidgetPredicate((w) => w is ToolbarAction && w.label == label)));

void main() {
  testOnMac('clicking a row opens the Transaction panel at its saved width; the row stays selected', (tester) async {
    await _open(
      tester,
      FakeSendChain()
        ..historyPages = [
          [_transfer('sent', from: 'qzMain', to: _bob)],
        ],
    );
    expect(find.byType(ActivityInspector), findsNothing);

    await _openRow(tester, 'sent');

    expect(find.byType(ActivityInspector), findsOne);
    expect(tester.getSize(find.byType(ActivityInspector)).width, InspectorWidthNotifier.initial);
    expect(_inPanel(find.text(_l10n.desktopActivityTransaction)), findsOne);
    expect(tester.widget<ActivityRowView>(find.byType(ActivityRowView)).isSelected, isTrue);
  });

  testOnMac('a completed send: its status, amount, kind and date, whom it paid, from where, the fee, what was paid, '
      'its hash to copy, its page and Share', (tester) async {
    final sent = _transfer('sent', from: 'qzMain', to: _bob);
    final outside = await _open(
      tester,
      FakeSendChain()
        ..historyPages = [
          [sent],
        ],
    );
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    await _openRow(tester, 'sent');

    expect(_inPanel(find.text(_l10n.activityDetailStatusCompleted.toUpperCase())), findsOne);
    expect(_inPanel(find.text(_money(tester, sent.amount))), findsOne);
    expect(
      _inPanel(
        find.text('${_l10n.activityDetailTitleSent} · ${DatetimeFormattingService.formatTxDateTime(sent.timestamp)}'),
      ),
      findsOne,
    );
    expect(_inPanel(find.text(_l10n.sendTxSubmittedToLabel.toUpperCase())), findsOne);
    expect(_inPanel(find.text(_bob)), findsOne);
    expect(_inPanel(find.text(_l10n.activityTxFrom)), findsOne);
    expect(_inPanel(find.byType(AccountLabel)), findsOne);
    expect(_inPanel(find.text(_l10n.swapReviewNetworkFee)), findsOne);
    expect(_inPanel(find.text(_money(tester, FakeSendChain.usualFee))), findsOne);
    expect(_inPanel(find.text(_l10n.desktopSendYouPaid)), findsOne);
    expect(_inPanel(find.text(_money(tester, sent.amount + FakeSendChain.usualFee))), findsOne);
    expect(_inPanel(find.text(_l10n.desktopActivityTransaction.toUpperCase())), findsOne);
    expect(_inPanel(find.text('0xsent')), findsOne);

    await tester.tap(_inPanel(find.text(_l10n.receiveCopy)));
    await tester.pump();
    expect(copied, ['0xsent']);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(_inPanel(find.text(_l10n.desktopViewInExplorer)));
    await tester.tap(_inPanel(find.text(_l10n.componentShare)));
    await tester.pumpAndSettle();
    expect(outside.opened, [Uri.parse('${AppConstants.explorerEndpoint}/transactions/0xsent')]);
    expect(outside.shared, ['${AppConstants.explorerEndpoint}/transactions/0xsent']);
  });

  testOnMac('a send in process turns its mark, and has no page or Share yet', (tester) async {
    await _open(tester, FakeSendChain(), reduceMotion: false);
    _container(tester)
        .read(pendingTransactionsProvider.notifier)
        .add(
          PendingTransactionEvent(
            tempId: 'sending',
            from: 'qzMain',
            to: _bob,
            amount: oneToken,
            timestamp: _now,
            fee: null,
          ),
        );
    await tester.pumpAndSettle();
    // The mark turns for good, so the panel is not waited on to settle.
    await tester.tap(find.byWidgetPredicate((widget) => widget is ActivityRowView && widget.id == 'sending'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_inPanel(find.text(_l10n.activityDetailStatusInProcess.toUpperCase())), findsOne);
    expect(_inPanel(find.byType(TerminalSpinner)), findsOne);
    expect(_action(tester, _l10n.desktopViewInExplorer).onPressed, isNull);
    expect(_action(tester, _l10n.componentShare).onPressed, isNull);
  });

  testOnMac('a scheduled send says how long until it runs, and has its page', (tester) async {
    final scheduled = ReversibleTransferEvent(
      id: 'scheduled',
      from: 'qzMain',
      to: _bob,
      amount: oneToken,
      timestamp: _now,
      txId: '0xtxid',
      status: ReversibleTransferStatus.SCHEDULED,
      scheduledAt: _now.add(const Duration(hours: 23, minutes: 41, seconds: 30)),
      blockNumber: 1,
      blockHash: '0xblock',
    );
    await _open(tester, FakeSendChain()..scheduledTransfers = [scheduled]);
    await _openRow(tester, 'scheduled');

    expect(_inPanel(find.text(_l10n.activityDetailStatusScheduled.toUpperCase())), findsOne);
    expect(_inPanel(find.text(_l10n.desktopActivityRunsIn(_l10n.activityTxTimeRemaining('00', '23', '41')))), findsOne);
    expect(_action(tester, _l10n.desktopViewInExplorer).onPressed, isNotNull);
  });

  testOnMac('a receipt says whom it came from, and no fee or what was paid', (tester) async {
    await _open(
      tester,
      FakeSendChain()
        ..historyPages = [
          [_transfer('received', from: _bob, to: 'qzMain')],
        ],
    );
    await _openRow(tester, 'received');

    expect(_inPanel(find.text(_l10n.activityTxFrom.toUpperCase())), findsOne);
    expect(_inPanel(find.text(_l10n.desktopSendYouPaid)), findsNothing);
    expect(_inPanel(find.text(_l10n.swapReviewNetworkFee)), findsNothing);
  });

  testOnMac('a private receipt is from "Encrypted"; a private send\'s fee is its transaction fee', (tester) async {
    WormholeTransferEvent private(String id, {required String from, required String to}) => WormholeTransferEvent(
      id: id,
      from: from,
      to: to,
      amount: oneToken,
      timestamp: _now.subtract(const Duration(hours: 3)),
      fee: FakeSendChain.usualFee,
      extrinsicHash: '0x$id',
      blockNumber: 1,
    );
    await _open(
      tester,
      FakeSendChain(),
      active: const RegularAccount(encryptedAccount),
      extra: [
        encryptedHistoryProvider.overrideWith(
          (ref, walletIndex) => AsyncValue.data([
            private('in', from: _bob, to: 'qzEncrypted'),
            private('out', from: 'qzEncrypted', to: _bob),
          ]),
        ),
      ],
    );

    await _openRow(tester, 'in');
    expect(_inPanel(find.text(_l10n.activitySenderEncrypted)), findsOne);

    await _openRow(tester, 'out');
    expect(_inPanel(find.text(_l10n.desktopSendTransactionFee)), findsOne);
    expect(_inPanel(find.text(_l10n.swapReviewNetworkFee)), findsNothing);
  });

  testOnMac('a proposal\'s step and a multisig\'s making list their facts in the desktop\'s words', (tester) async {
    final approved = MultisigProposalApprovedEvent(
      id: 'approved',
      approverId: 'qzMain',
      multisigAddress: teamMultisig.accountId,
      recipient: _bob,
      amount: oneToken * BigInt.from(500),
      proposalId: 4,
      approvalsCount: 2,
      timestamp: _now.subtract(const Duration(hours: 2)),
      blockNumber: 1,
      blockHash: '0xblock',
      fee: FakeSendChain.usualFee,
      extrinsicHash: '0xapproved',
    );
    final made = MultisigCreatedEvent(
      id: 'made',
      creatorId: 'qzOther',
      multisigAddress: 'qzNewTeam',
      threshold: 2,
      nonce: BigInt.zero,
      signers: const ['qzMain', 'qzOther'],
      palletFee: oneToken,
      networkFee: FakeSendChain.usualFee,
      timestamp: _now.subtract(const Duration(days: 1)),
      blockNumber: 1,
      blockHash: '0xblock',
      extrinsicHash: '0xmade',
    );
    await _open(
      tester,
      FakeSendChain()
        ..historyPages = [
          [approved, made],
        ],
      multisigs: [teamMultisig],
    );

    await _openRow(tester, 'approved');
    for (final label in [
      _l10n.activityTxMultisigLabel,
      _l10n.desktopActivityAmount,
      _l10n.desktopProposeApprovals,
      _l10n.swapReviewNetworkFee,
    ]) {
      expect(_inPanel(find.text(label)), findsOne, reason: label);
    }
    expect(_inPanel(find.text(teamMultisig.name)), findsOne, reason: 'its own multisig by badge and name');

    await _openRow(tester, 'made');
    expect(_inPanel(find.text('—')), findsOne, reason: 'another signer paid for it');
    for (final label in [
      _l10n.desktopActivityThreshold,
      _l10n.desktopActivitySigners,
      _l10n.desktopActivityCreatedBy,
      _l10n.desktopActivityCreationFee,
    ]) {
      expect(_inPanel(find.text(label)), findsOne, reason: label);
    }
  });

  group('a proposal', () {
    MultisigProposal proposal({required MultisigProposalStatus status}) => MultisigProposal(
      entityId: 'proposal-${status.name}',
      id: 1,
      multisigAddress: teamMultisig.accountId,
      proposer: 'qzMain',
      createdAt: _now.subtract(const Duration(hours: 5)),
      updatedAt: _now.subtract(const Duration(hours: 5)),
      pallet: '',
      call: '',
      recipient: _bob,
      amount: oneToken * BigInt.from(250),
      expiryBlock: 1284220,
      approvals: const ['qzMain'],
      deposit: oneToken,
      status: status,
      threshold: teamMultisig.threshold,
      signerCount: teamMultisig.signers.length,
    );

    Future<_Outside> openTeam(WidgetTester tester, FakeSendChain chain) =>
        _open(tester, chain, active: MultisigDisplayAccount(teamMultisig), multisigs: [teamMultisig]);

    testOnMac('open, it shows read only: where it stands, what it moves, to whom, how far, until when, its deposit, '
        'who proposed it, and its page', (tester) async {
      final open = proposal(status: MultisigProposalStatus.active);
      // Proposed by another signer, and changed before the first.
      final byAnother = MultisigProposal(
        entityId: 'by-another',
        id: 2,
        multisigAddress: teamMultisig.accountId,
        proposer: _bob,
        createdAt: _now.subtract(const Duration(hours: 10)),
        updatedAt: _now.subtract(const Duration(hours: 10)),
        pallet: '',
        call: '',
        recipient: 'qzMain',
        amount: oneToken,
        expiryBlock: 1284220,
        approvals: const [],
        deposit: oneToken,
        status: MultisigProposalStatus.active,
        threshold: 2,
        signerCount: 2,
      );
      final outside = await openTeam(tester, FakeSendChain()..openProposals = [open, byAnother]);

      await tester.tap(find.byType(OpenProposalRowView).first);
      await tester.pumpAndSettle();

      expect(_inPanel(find.text(_l10n.multisigProposalTitle)), findsWidgets);
      expect(_inPanel(find.text(_l10n.multisigStatusActive)), findsOne);
      expect(_inPanel(find.text(_money(tester, open.amount))), findsOne);
      expect(_inPanel(find.text(_bob)), findsOne);
      for (final label in [
        _l10n.activityTxMultisigLabel,
        _l10n.desktopProposeApprovals,
        _l10n.desktopProposeExpires,
        _l10n.desktopProposeDeposit,
        _l10n.desktopProposeProposedBy,
      ]) {
        expect(_inPanel(find.text(label)), findsOne, reason: label);
      }
      expect(_inPanel(find.text(_l10n.multisigExpiresBlockOnly(1284220))), findsOne);
      expect(_inPanel(find.text(_l10n.multisigApproveButton)), findsNothing);
      expect(_inPanel(find.text(_l10n.multisigExecuteButton)), findsNothing);
      expect(_inPanel(find.text(_l10n.multisigCancelProposalButton)), findsNothing);

      await tester.tap(_inPanel(find.text(_l10n.desktopViewInExplorer)));
      await tester.pumpAndSettle();
      expect(outside.opened, [
        Uri.parse('${AppConstants.explorerEndpoint}/multisig-proposals/${open.explorerProposalId}'),
      ]);
    });

    testOnMac('past, it shows how it ended', (tester) async {
      await openTeam(tester, FakeSendChain()..pastProposals = [proposal(status: MultisigProposalStatus.executed)]);

      await _openRow(tester, 'proposal-executed');

      expect(_inPanel(find.text(_l10n.multisigStatusExecuted)), findsOne);
    });
  });

  testOnMac('✕ closes the panel', (tester) async {
    await _open(
      tester,
      FakeSendChain()
        ..historyPages = [
          [_transfer('sent', from: 'qzMain', to: _bob)],
        ],
    );
    await _openRow(tester, 'sent');

    await tester.tap(find.byKey(ActivityInspector.closeKey));
    await tester.pumpAndSettle();

    expect(find.byType(ActivityInspector), findsNothing);
    expect(_container(tester).read(openedActivityProvider), isNull);
  });

  testOnMac('a send that settles while open stays open as its settled self; one that leaves the list closes it', (
    tester,
  ) async {
    final chain = FakeSendChain();
    await _open(tester, chain);
    final pending = _container(tester).read(pendingTransactionsProvider.notifier);
    pending.add(
      PendingTransactionEvent(
        tempId: 'sending',
        from: 'qzMain',
        to: _bob,
        amount: oneToken,
        timestamp: _now,
        fee: null,
        extrinsicHash: '0xsettles',
      ),
    );
    await tester.pumpAndSettle();
    await _openRow(tester, 'sending');
    expect(_inPanel(find.text(_l10n.activityDetailStatusInProcess.toUpperCase())), findsOne);

    Future<void> reread() async {
      final params = activeAccountFilteredParams(const RegularAccount(mainAccount), TransactionFilter.all)!;
      await _container(tester).read(filteredPaginationControllerProviderFamily(params).notifier).silentRefresh();
      await tester.pumpAndSettle();
    }

    // In a block now, under the indexer's own id, and no longer pending here.
    chain.historyPages = [
      [
        TransferEvent(
          id: 'indexed',
          from: 'qzMain',
          to: _bob,
          amount: oneToken,
          timestamp: _now,
          fee: FakeSendChain.usualFee,
          extrinsicHash: '0xsettles',
          blockNumber: 2,
          blockHash: '0xblock2',
        ),
      ],
    ];
    pending.remove('sending');
    await reread();
    expect(find.byType(ActivityInspector), findsOne);
    expect(_inPanel(find.text(_l10n.activityDetailStatusCompleted.toUpperCase())), findsOne);

    chain.historyPages = const [];
    await reread();
    expect(find.byType(ActivityInspector), findsNothing);
  });

  testOnMac('the panel resizes from its gap, within 360 and 480, and keeps its width', (tester) async {
    final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount));
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: settings,
        balances: oneTokenEach,
        chain: FakeSendChain()
          ..historyPages = [
            [_transfer('sent', from: 'qzMain', to: _bob)],
          ],
      ),
    );
    await _openRow(tester, 'sent');
    final gap = find.byType(PanelResizeHandle).last;

    await tester.timedDrag(gap, const Offset(-60, 0), const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ActivityInspector)).width, 440);
    expect(settings.strings[InspectorWidthNotifier.settingsKey], '440.0');

    await tester.timedDrag(gap, const Offset(-200, 0), const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ActivityInspector)).width, InspectorWidthNotifier.maximum);
  });
}
