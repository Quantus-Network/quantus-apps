import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/models/fiat_currency.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/copy_icon_button.dart';
import 'package:resonance_network_wallet/v2/components/explorer_link.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  CheckphraseText.resolveOverride = (_) async => 'Stand-Envelope-Topic-Term-Help';
  final me = makeAccount(1);
  final other = makeAccount(2);

  TransferEvent transfer({required String from, required String to}) => TransferEvent(
    id: 'tx-1',
    from: from,
    to: to,
    amount: BigInt.from(300),
    timestamp: DateTime(2026, 9, 6),
    fee: BigInt.one,
    extrinsicHash: '0x9cbe',
    blockNumber: 1,
    blockHash: '0xblock',
  );

  Future<bool?> openSheet(WidgetTester tester, TransactionEvent tx, {Account? active}) async {
    bool? capturedIsSend;
    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showTransactionDetailSheet(context, tx, me.accountId),
          child: const Text('open'),
        ),
      ),
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(active ?? me))),
        txAmountDisplayProvider.overrideWithValue((
          BigInt amount, {
          required bool isSend,
          int tokenDecimals = 12,
          bool withTokenSymbol = true,
          bool withSignPrefix = true,
        }) {
          capturedIsSend = isSend;
          return CurrencyDisplayState(
            primaryAmount: '${isSend ? '-' : '+'}$amount',
            secondaryAmount: '',
            selectedFiat: FiatCurrency.usd,
          );
        }),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return capturedIsSend;
  }

  testWidgets('a received transfer is formatted as an inflow', (tester) async {
    final isSend = await openSheet(tester, transfer(from: other.accountId, to: me.accountId));

    expect(isSend, isFalse);
    expect(find.textContaining('+300'), findsOneWidget);
    expect(find.text(AddressFormattingService.formatAddress(other.accountId, ellipses: '.......')), findsOneWidget);
    expect(find.text('Stand-Envelope-Topic-Term-Help'), findsNothing);
  });

  testWidgets('a wormhole receipt names its sender as encrypted', (tester) async {
    await openSheet(
      tester,
      WormholeTransferEvent(
        id: '0xexit',
        from: other.accountId,
        to: me.accountId,
        amount: BigInt.from(300),
        timestamp: DateTime(2026, 9, 6),
        fee: BigInt.zero,
        extrinsicHash: '0xexit',
        blockNumber: 1,
      ),
    );

    expect(find.text('Encrypted'), findsOneWidget);
    expect(find.text(AddressFormattingService.formatAddress(other.accountId, ellipses: '.......')), findsNothing);
  });

  testWidgets('a private send without an attributable recipient names the aggregated batch', (tester) async {
    await openSheet(
      tester,
      WormholeTransferEvent(
        id: '0xbundle',
        from: me.accountId,
        to: '',
        amount: BigInt.from(300),
        timestamp: DateTime(2026, 9, 6),
        fee: BigInt.zero,
        extrinsicHash: '0xbundle',
        blockNumber: 1,
      ),
    );

    expect(find.text('Aggregated batch, recipient not recorded'), findsOneWidget);
  });

  testWidgets('a multi-batch private send opens a page listing every batch with its nullifiers', (tester) async {
    WormholeUtxo input(String nullifier) => WormholeUtxo(
      transfer: WormholeTransfer(
        id: nullifier,
        blockHeight: 1,
        timestamp: DateTime(2026, 9, 6),
        fromId: 'qzmint',
        toId: me.accountId,
        amount: BigInt.from(500),
        toHash: '',
        leafIndex: BigInt.zero,
        transferCount: BigInt.zero,
        extrinsicId: '',
        viaWormhole: true,
      ),
      owner: WormholeAddressInfo(index: 0, address: me.accountId, secretHex: ''),
      nullifierHex: nullifier,
    );
    WormholeSendBatch batch(String hash, String nullifier) => WormholeSendBatch(
      extrinsicId: hash,
      blockHeight: 1,
      timestamp: DateTime(2026, 9, 6),
      inputs: [input(nullifier)],
      sentToken: BigInt.from(400),
      changeToken: BigInt.zero,
      feeToken: BigInt.from(100),
    );
    await openSheet(
      tester,
      WormholeTransferEvent(
        id: '0xsecondbatch0000',
        from: me.accountId,
        to: other.accountId,
        amount: BigInt.from(800),
        timestamp: DateTime(2026, 9, 6),
        fee: BigInt.from(200),
        extrinsicHash: '0xsecondbatch0000',
        blockNumber: 1,
        batches: [batch('0xfirstbatch00000', '0xnullifier111111'), batch('0xsecondbatch0000', '0xnullifier222222')],
      ),
    );

    await tester.tap(find.text('Wormhole details'));
    await tester.pumpAndSettle();

    expect(find.text('Batch 1 of 2'), findsOneWidget);
    expect(find.text('Batch 2 of 2'), findsOneWidget);
    for (final shown in ['0xfirstbatch00000', '0xnullifier111111', '0xnullifier222222']) {
      expect(find.text(AddressFormattingService.formatActivityDetailExtrinsicHash(shown)), findsOneWidget);
    }
  });

  testWidgets('the counterparty address and the transaction hash copy whole', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    await openSheet(tester, transfer(from: other.accountId, to: me.accountId));

    final buttons = find.byType(CopyIconButton);
    expect(buttons, findsNWidgets(2));
    expect(tester.widget<CopyIconButton>(buttons.first).text, other.accountId);
    expect(tester.widget<CopyIconButton>(buttons.last).text, '0x9cbe');

    await tester.tap(buttons.first);
    await tester.pump();
    await tester.tap(buttons.last);
    await tester.pump();
    expect(copied, [other.accountId, '0x9cbe']);
    await tester.pump(const Duration(seconds: 10));
  });

  group('what the sheet says of each kind of transaction', () {
    const colors = AppColorsV3.dark();
    final other = makeAccount(2).accountId;
    final recipient = makeAccount(3).accountId;
    final msig = makeMultisigAccount();
    final at = DateTime(2026, 9, 6);
    String link(String path) => '${AppConstants.explorerEndpoint}/$path';

    /// Opens [tx]'s sheet and reads its title, its status and that status's
    /// colour, and the explorer link with whether it can be followed.
    Future<(String, String, Color?, String?, bool)> sheetOf(
      WidgetTester tester,
      TransactionEvent tx, {
      Account? active,
    }) async {
      await openSheet(tester, tx, active: active);
      final title = tester.widget<BottomSheetContainer>(find.byType(BottomSheetContainer)).title;
      // The text beside the Status label, in the same row.
      final statusRow = find.ancestor(of: find.text(l10n.activityDetailStatus), matching: find.byType(Row)).first;
      final status = tester
          .widgetList<Text>(find.descendant(of: statusRow, matching: find.byType(Text)))
          .singleWhere((text) => text.data != l10n.activityDetailStatus);
      final explorer = tester.widget<ExplorerLink>(find.byType(ExplorerLink));
      return (title, status.data!, status.style?.color, explorer.url, explorer.enabled);
    }

    final completed = (l10n.activityDetailStatusCompleted, colors.semanticSage);
    final inProcess = (l10n.activityDetailStatusInProcess, colors.semanticGlacier);
    final scheduled = (l10n.activityDetailStatusScheduled, colors.semanticGlacier);

    ReversibleTransferEvent reversible({required String from, required ReversibleTransferStatus status}) =>
        ReversibleTransferEvent(
          id: 'reversible',
          from: from,
          to: from == me.accountId ? other : me.accountId,
          amount: BigInt.from(300),
          timestamp: at,
          txId: '0xtxid',
          status: status,
          scheduledAt: DateTime.now().add(const Duration(days: 1)),
          blockNumber: 1,
          blockHash: '0xblock',
        );

    WormholeTransferEvent privateSend() => WormholeTransferEvent(
      id: 'wormhole',
      from: me.accountId,
      to: other,
      amount: BigInt.from(300),
      timestamp: at,
      fee: BigInt.one,
      extrinsicHash: '0xwormhole',
      blockNumber: 1,
    );

    final cases = <(String, TransactionEvent Function(), Account?, String, (String, Color), String?, bool)>[
      (
        'sent',
        () => transfer(from: me.accountId, to: other),
        null,
        l10n.activityDetailTitleSent,
        completed,
        link('transactions/0x9cbe'),
        true,
      ),
      (
        'received',
        () => transfer(from: other, to: me.accountId),
        null,
        l10n.activityDetailTitleReceived,
        completed,
        link('transactions/0x9cbe'),
        true,
      ),
      (
        'sending, not yet in a block',
        () => PendingTransactionEvent(
          tempId: 'pending',
          from: me.accountId,
          to: other,
          amount: BigInt.from(300),
          timestamp: at,
          fee: BigInt.one,
        ),
        null,
        l10n.activityDetailTitleSending,
        inProcess,
        null,
        false,
      ),
      (
        'sending, broadcast',
        () => PendingTransactionEvent(
          tempId: 'pending',
          from: me.accountId,
          to: other,
          amount: BigInt.from(300),
          timestamp: at,
          fee: BigInt.one,
          extrinsicHash: '0xpending',
        ),
        null,
        l10n.activityDetailTitleSending,
        inProcess,
        link('transactions/0xpending'),
        false,
      ),
      (
        'a scheduled send',
        () => reversible(from: me.accountId, status: ReversibleTransferStatus.SCHEDULED),
        null,
        l10n.activityDetailTitleScheduled,
        scheduled,
        link('transactions/scheduled-reversible/0xtxid'),
        true,
      ),
      (
        'a scheduled receipt',
        () => reversible(from: other, status: ReversibleTransferStatus.SCHEDULED),
        null,
        l10n.activityDetailTitleReceiving,
        scheduled,
        link('transactions/scheduled-reversible/0xtxid'),
        true,
      ),
      (
        'a scheduled send that ran',
        () => reversible(from: me.accountId, status: ReversibleTransferStatus.EXECUTED),
        null,
        l10n.activityDetailTitleSent,
        completed,
        link('transactions/executed-reversible/0xtxid'),
        true,
      ),
      (
        'a scheduled send that was cancelled',
        () => reversible(from: me.accountId, status: ReversibleTransferStatus.CANCELLED),
        null,
        l10n.activityDetailTitleSent,
        completed,
        link('transactions/cancelled-reversible/0xtxid'),
        true,
      ),
      (
        'a private send, seen from a transparent account',
        privateSend,
        null,
        l10n.activityDetailTitleSent,
        completed,
        link('transactions/wormhole/0xwormhole'),
        true,
      ),
      (
        'a private send, seen from the encrypted account',
        privateSend,
        makeAccount(1, accountType: AccountType.encrypted),
        l10n.activityDetailTitlePrivateSent,
        completed,
        link('transactions/wormhole/0xwormhole'),
        true,
      ),
      (
        'a mining reward',
        () => MinerRewardEvent(
          id: 'reward',
          miner: me.accountId,
          reward: BigInt.from(9),
          timestamp: at,
          blockNumber: 1,
          blockHash: '0xrewardblock',
        ),
        null,
        l10n.activityDetailTitleReceived,
        completed,
        link('miner-rewards/0xrewardblock'),
        true,
      ),
      (
        'a proposal being made',
        () => PendingMultisigProposalEvent.create(
          msig: msig,
          proposerId: me.accountId,
          recipient: recipient,
          amount: BigInt.from(500),
          expiryBlock: 1000,
          fee: BigInt.from(3),
          deposit: BigInt.from(2),
          palletFee: BigInt.one,
        ).copyWith(extrinsicHash: '0xproposing'),
        null,
        l10n.activityDetailTitleProposing,
        inProcess,
        link('multisig-proposal-created/0xproposing'),
        false,
      ),
      (
        'a proposal made',
        () => MultisigProposalCreatedEvent(
          id: 'created',
          proposerId: me.accountId,
          multisigAddress: msig.accountId,
          recipient: recipient,
          amount: BigInt.from(500),
          palletFee: BigInt.one,
          deposit: BigInt.from(2),
          timestamp: at,
          blockNumber: 1,
          blockHash: '0xblock',
          fee: BigInt.from(3),
          extrinsicHash: '0xcreated',
        ),
        null,
        l10n.activityDetailTitleProposalCreated,
        completed,
        link('multisig-proposal-created/0xcreated'),
        true,
      ),
      (
        'an approval',
        () => MultisigProposalApprovedEvent(
          id: 'approved',
          approverId: me.accountId,
          multisigAddress: msig.accountId,
          recipient: recipient,
          amount: BigInt.from(500),
          proposalId: 4,
          approvalsCount: 2,
          timestamp: at,
          blockNumber: 1,
          blockHash: '0xblock',
          fee: BigInt.from(7),
          extrinsicHash: '0xapproved',
        ),
        null,
        l10n.activityDetailTitleProposalApproved,
        completed,
        link('multisig-signer-approved/0xapproved'),
        true,
      ),
      (
        'an execution under way',
        () => PendingMultisigExecutionEvent.create(
          multisigAddress: msig.accountId,
          proposalId: 4,
          executorId: me.accountId,
          recipient: recipient,
          amount: BigInt.from(500),
          fee: BigInt.from(6),
        ).copyWith(extrinsicHash: '0xexecuting'),
        null,
        l10n.activityDetailTitleExecuting,
        inProcess,
        link('transactions/0xexecuting'),
        false,
      ),
      (
        'an execution',
        () => MultisigProposalExecutedEvent(
          id: 'executed',
          executorId: me.accountId,
          multisigAddress: msig.accountId,
          recipient: recipient,
          amount: BigInt.from(500),
          proposalId: 4,
          approvers: [me.accountId, other],
          result: 'ok',
          timestamp: at,
          blockNumber: 1,
          blockHash: '0xblock',
          fee: BigInt.from(6),
          extrinsicHash: '0xexecuted',
        ),
        null,
        l10n.activityDetailTitleProposalExecuted,
        completed,
        link('multisig-proposal-executed/0xexecuted'),
        true,
      ),
      (
        'a cancellation under way',
        () => PendingMultisigCancellationEvent.create(
          multisigAddress: msig.accountId,
          proposalId: 4,
          proposerId: me.accountId,
          recipient: recipient,
          amount: BigInt.from(500),
          fee: BigInt.from(5),
        ).copyWith(extrinsicHash: '0xcancelling'),
        null,
        l10n.activityDetailTitleCancelling,
        inProcess,
        link('transactions/0xcancelling'),
        false,
      ),
      (
        'a cancellation',
        () => MultisigProposalCancelledEvent(
          id: 'cancelled',
          proposerId: me.accountId,
          multisigAddress: msig.accountId,
          recipient: recipient,
          amount: BigInt.from(500),
          proposalId: 4,
          timestamp: at,
          blockNumber: 1,
          blockHash: '0xblock',
          fee: BigInt.from(5),
          extrinsicHash: '0xcancelled',
        ),
        null,
        l10n.activityDetailTitleProposalCancelled,
        completed,
        link('multisig-proposal-cancelled/0xcancelled'),
        true,
      ),
      (
        'a multisig being created',
        () => PendingMultisigCreationEvent(
          tempId: 'creating',
          creatorId: me.accountId,
          multisigAddress: msig.accountId,
          threshold: 2,
          nonce: BigInt.zero,
          signers: [me.accountId, other],
          palletFee: BigInt.from(4),
          networkFee: BigInt.from(3),
          timestamp: at,
          extrinsicHash: '0xcreating',
        ),
        null,
        l10n.activityDetailTitleMultisigCreating,
        inProcess,
        link('transactions/0xcreating'),
        false,
      ),
      (
        'a multisig created',
        () => MultisigCreatedEvent(
          id: 'multisig',
          creatorId: me.accountId,
          multisigAddress: msig.accountId,
          threshold: 2,
          nonce: BigInt.zero,
          signers: [me.accountId, other],
          palletFee: BigInt.from(4),
          networkFee: BigInt.from(3),
          timestamp: at,
          blockNumber: 1,
          blockHash: '0xblock',
          extrinsicHash: '0xmultisig',
        ),
        null,
        l10n.activityDetailTitleMultisigCreated,
        completed,
        link('multisig-created/0xmultisig'),
        true,
      ),
    ];

    for (final (name, tx, active, title, (status, statusColor), url, enabled) in cases) {
      testWidgets(name, (tester) async {
        expect(await sheetOf(tester, tx(), active: active), (title, status, statusColor, url, enabled));
      });
    }
  });

  testWidgets('a sent transfer is formatted as an outflow', (tester) async {
    final isSend = await openSheet(tester, transfer(from: me.accountId, to: other.accountId));

    expect(isSend, isTrue);
    expect(find.textContaining('-300'), findsOneWidget);
  });

  testWidgets('the share button hands the explorer link to the system share sheet', (tester) async {
    Map? shared;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async {
        shared = call.arguments as Map;
        return '';
      },
    );
    await openSheet(tester, transfer(from: me.accountId, to: other.accountId));

    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pump();

    final button = tester.getRect(find.byType(IconButton));
    expect(shared?['text'], '${AppConstants.explorerEndpoint}/transactions/0x9cbe');
    expect(shared?['originX'], button.left);
    expect(shared?['originY'], button.top);
    expect(shared?['originWidth'], button.width);
    expect(shared?['originHeight'], button.height);
  });
}
