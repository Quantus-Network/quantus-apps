import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

import '../fakes.dart';

/// What a row of the activity list shows, as one value to compare.
typedef _Row = ({
  String label,
  String time,
  (Color, Color, Color, Color, Color) colors,
  IconData? icon,
  bool isSend,
  BigInt amount,
  bool hideAmount,
  String counterparty,
  String? prefix,
});

_Row _rowOf(TxItemData data) => (
  label: data.label,
  time: data.timeLabel,
  colors: (data.iconBg, data.iconColor, data.labelColor, data.amountColor, data.borderColor),
  icon: data.customIcon,
  isSend: data.isSend,
  amount: data.amount,
  hideAmount: data.hideAmount,
  counterparty: data.counterpartyAddr,
  prefix: data.counterpartyDirectionLabel,
);

/// Pins what each kind of activity row shows on the phone, so that moving the
/// rules that decide it out of the widget file changes none of it.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const colors = AppColorsV3.dark();
  final me = makeAccount(1).accountId;
  final other = makeAccount(2).accountId;
  final recipient = makeAccount(3).accountId;
  final msig = makeMultisigAccount();

  // The row's colours: settled, arriving, and on its way out.
  final settledSend = (
    Colors.transparent,
    colors.textContent,
    colors.textContent,
    colors.textContent,
    colors.borderHairline,
  );
  final settledReceipt = (
    Colors.transparent,
    colors.textContent,
    colors.textContent,
    colors.semanticSage,
    colors.borderHairline,
  );
  final arriving = (
    colors.semanticSage.useOpacity(0.08),
    colors.semanticSage,
    colors.semanticSage,
    colors.semanticSage,
    colors.semanticSage.useOpacity(0.15),
  );
  final leaving = (
    glacierFill(colors),
    colors.semanticGlacier,
    colors.semanticGlacier,
    colors.semanticGlacier,
    glacierStroke(colors),
  );

  String short(String address) => AddressFormattingService.formatAddress(address, prefix: 5, postFix: 3);

  // Far enough from a unit's edge that the clock moving on while a test runs
  // changes nothing.
  final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5, seconds: 30));
  final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3, minutes: 10));
  final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2, hours: 1));
  final aMomentAgo = DateTime.now().subtract(const Duration(seconds: 20));

  _Row rowOf(TransactionEvent tx, {bool isPrivate = false, String? accountId}) =>
      _rowOf(TxItemData.from(tx, accountId ?? me, colors, l10n, isPrivate: isPrivate));

  TransferEvent transfer({required String from, required String to, DateTime? at}) => TransferEvent(
    id: 'tx',
    from: from,
    to: to,
    amount: BigInt.from(300),
    timestamp: at ?? fiveMinutesAgo,
    fee: BigInt.one,
    extrinsicHash: '0xhash',
    blockNumber: 1,
    blockHash: '0xblock',
  );

  PendingTransactionEvent pending({required String from, required String to}) => PendingTransactionEvent(
    tempId: 'pending',
    from: from,
    to: to,
    amount: BigInt.from(300),
    timestamp: DateTime.now(),
    fee: BigInt.one,
  );

  ReversibleTransferEvent reversible({
    required String from,
    required String to,
    ReversibleTransferStatus status = ReversibleTransferStatus.SCHEDULED,
  }) => ReversibleTransferEvent(
    id: 'reversible',
    from: from,
    to: to,
    amount: BigInt.from(300),
    timestamp: fiveMinutesAgo,
    txId: '0xtxid',
    status: status,
    scheduledAt: DateTime.now().add(const Duration(days: 1, hours: 2, minutes: 3, seconds: 30)),
    blockNumber: 1,
    blockHash: '0xblock',
  );

  WormholeTransferEvent wormhole({required String from, required String to}) => WormholeTransferEvent(
    id: 'wormhole',
    from: from,
    to: to,
    amount: BigInt.from(300),
    timestamp: fiveMinutesAgo,
    fee: BigInt.one,
    extrinsicHash: '0xwormhole',
    blockNumber: 1,
  );

  MultisigProposal proposal() => MultisigProposal(
    entityId: 'proposal-entity',
    id: 4,
    multisigAddress: msig.accountId,
    proposer: me,
    createdAt: twoDaysAgo,
    updatedAt: twoDaysAgo,
    pallet: 'Balances',
    call: 'transfer_allow_death',
    recipient: recipient,
    amount: BigInt.from(500),
    expiryBlock: 1000,
    approvals: [me],
    deposit: BigInt.from(2),
    status: MultisigProposalStatus.active,
    threshold: 2,
    signerCount: 3,
  );

  group('transfers', () {
    test('sent: settled, the recipient named after "To"', () {
      expect(rowOf(transfer(from: me, to: other)), (
        label: l10n.activityTxSent,
        time: l10n.activityTxTimeMinutesAgo(5),
        colors: settledSend,
        icon: null,
        isSend: true,
        amount: BigInt.from(300),
        hideAmount: false,
        counterparty: short(other),
        prefix: null,
      ));
    });

    test('received: settled, the amount in sage, the sender named after "From"', () {
      expect(rowOf(transfer(from: other, to: me, at: threeHoursAgo)), (
        label: l10n.activityTxReceived,
        time: l10n.activityTxTimeHoursAgo(3),
        colors: settledReceipt,
        icon: null,
        isSend: false,
        amount: BigInt.from(300),
        hideAmount: false,
        counterparty: short(other),
        prefix: null,
      ));
    });

    test('a moment ago says now; days ago in days', () {
      expect(rowOf(transfer(from: me, to: other, at: aMomentAgo)).time, l10n.activityTxTimeNow);
      expect(rowOf(transfer(from: me, to: other, at: twoDaysAgo)).time, l10n.activityTxTimeDaysAgo(2));
    });

    test('of the encrypted account, sent and received privately', () {
      expect(rowOf(transfer(from: me, to: other), isPrivate: true).label, l10n.activityTxPrivateSent);
      expect(rowOf(transfer(from: other, to: me), isPrivate: true).label, l10n.activityTxPrivateReceived);
    });

    test('a mining reward is received from the reward source', () {
      final reward = MinerRewardEvent(
        id: 'reward',
        miner: me,
        reward: BigInt.from(9),
        timestamp: fiveMinutesAgo,
        blockNumber: 1,
        blockHash: '0xblock',
      );

      expect(rowOf(reward), (
        label: l10n.activityTxReceived,
        time: l10n.activityTxTimeMinutesAgo(5),
        colors: settledReceipt,
        icon: null,
        isSend: false,
        amount: BigInt.from(9),
        hideAmount: false,
        counterparty: short(reward.from),
        prefix: null,
      ));
    });
  });

  group('transfers not yet settled', () {
    test('sending: on its way out, now', () {
      expect(rowOf(pending(from: me, to: other)), (
        label: l10n.activityTxSending,
        time: l10n.activityTxTimeNow,
        colors: leaving,
        icon: null,
        isSend: true,
        amount: BigInt.from(300),
        hideAmount: false,
        counterparty: short(other),
        prefix: null,
      ));
    });

    test('receiving: arriving, now', () {
      expect(rowOf(pending(from: other, to: me)), (
        label: l10n.activityTxReceiving,
        time: l10n.activityTxTimeNow,
        colors: arriving,
        icon: null,
        isSend: false,
        amount: BigInt.from(300),
        hideAmount: false,
        counterparty: short(other),
        prefix: null,
      ));
    });

    test('of the encrypted account, sending and receiving privately', () {
      expect(rowOf(pending(from: me, to: other), isPrivate: true).label, l10n.activityTxPrivatelySending);
      expect(rowOf(pending(from: other, to: me), isPrivate: true).label, l10n.activityTxPrivatelyReceiving);
    });

    test('a scheduled send is pending, with the time left until it runs', () {
      expect(rowOf(reversible(from: me, to: other)), (
        label: l10n.activityTxPending,
        time: l10n.activityTxTimeRemaining('01', '02', '03'),
        colors: leaving,
        icon: null,
        isSend: true,
        amount: BigInt.from(300),
        hideAmount: false,
        counterparty: short(other),
        prefix: null,
      ));
    });

    test('a scheduled receipt is receiving, arriving, with the time left', () {
      expect(rowOf(reversible(from: other, to: me)), (
        label: l10n.activityTxReceiving,
        time: l10n.activityTxTimeRemaining('01', '02', '03'),
        colors: arriving,
        icon: null,
        isSend: false,
        amount: BigInt.from(300),
        hideAmount: false,
        counterparty: short(other),
        prefix: null,
      ));
      expect(rowOf(reversible(from: other, to: me), isPrivate: true).label, l10n.activityTxPrivatelyReceiving);
    });

    test('a scheduled transfer that ran is settled', () {
      final ran = rowOf(reversible(from: me, to: other, status: ReversibleTransferStatus.EXECUTED));

      expect((ran.label, ran.time, ran.colors), (l10n.activityTxSent, l10n.activityTxTimeMinutesAgo(5), settledSend));
    });
  });

  group('private sends', () {
    test('a private receipt names its sender as encrypted, after "From"', () {
      final row = rowOf(wormhole(from: other, to: me), isPrivate: true);

      expect((row.counterparty, row.prefix), (l10n.activitySenderEncrypted, null));
    });

    test('a private send with no known recipient names the batch, with no prefix', () {
      final row = rowOf(wormhole(from: me, to: ''), isPrivate: true);

      expect(
        (row.label, row.counterparty, row.prefix),
        (l10n.activityTxPrivateSent, l10n.activityTxAggregatedBatch, ''),
      );
    });

    test('a private send with a known recipient names it', () {
      final row = rowOf(wormhole(from: me, to: other), isPrivate: true);

      expect((row.counterparty, row.prefix), (short(other), null));
    });
  });

  group('multisig proposals', () {
    final proposalIcon = Icons.how_to_vote_outlined;

    test('proposing: on its way out, now, the amount proposed, to its recipient', () {
      final event = PendingMultisigProposalEvent.create(
        msig: msig,
        proposerId: me,
        recipient: recipient,
        amount: BigInt.from(500),
        expiryBlock: 1000,
        fee: BigInt.from(3),
        deposit: BigInt.from(2),
        palletFee: BigInt.one,
      );

      expect(rowOf(event), (
        label: l10n.activityTxProposing,
        time: l10n.activityTxTimeNow,
        colors: leaving,
        icon: proposalIcon,
        isSend: true,
        amount: BigInt.from(500),
        hideAmount: false,
        counterparty: short(recipient),
        prefix: null,
      ));
    });

    test('created: settled, the amount proposed', () {
      final event = MultisigProposalCreatedEvent(
        id: 'created',
        proposerId: me,
        multisigAddress: msig.accountId,
        recipient: recipient,
        amount: BigInt.from(500),
        palletFee: BigInt.one,
        deposit: BigInt.from(2),
        timestamp: fiveMinutesAgo,
        blockNumber: 1,
        blockHash: '0xblock',
        fee: BigInt.from(3),
        extrinsicHash: '0xcreated',
      );

      expect(rowOf(event), (
        label: l10n.activityTxProposalCreated,
        time: l10n.activityTxTimeMinutesAgo(5),
        colors: settledSend,
        icon: proposalIcon,
        isSend: true,
        amount: BigInt.from(500),
        hideAmount: false,
        counterparty: short(recipient),
        prefix: null,
      ));
    });

    MultisigProposalApprovedEvent approved({BigInt? fee}) => MultisigProposalApprovedEvent(
      id: 'approved',
      approverId: me,
      multisigAddress: msig.accountId,
      recipient: recipient,
      amount: BigInt.from(500),
      proposalId: 4,
      approvalsCount: 2,
      timestamp: fiveMinutesAgo,
      blockNumber: 1,
      blockHash: '0xblock',
      fee: fee,
    );

    test('approved: settled, the fee paid to approve', () {
      expect(rowOf(approved(fee: BigInt.from(7))), (
        label: l10n.activityTxProposalApproved,
        time: l10n.activityTxTimeMinutesAgo(5),
        colors: settledSend,
        icon: proposalIcon,
        isSend: true,
        amount: BigInt.from(7),
        hideAmount: false,
        counterparty: short(recipient),
        prefix: null,
      ));
    });

    test('approved with no fee known: no amount', () {
      final row = rowOf(approved());

      expect((row.amount, row.hideAmount), (BigInt.zero, true));
    });

    test('executing: on its way out, now, the fee to execute', () {
      final event = PendingMultisigExecutionEvent.create(
        multisigAddress: msig.accountId,
        proposalId: 4,
        executorId: me,
        recipient: recipient,
        amount: BigInt.from(500),
        fee: BigInt.from(6),
      );

      expect(rowOf(event), (
        label: l10n.activityTxExecuting,
        time: l10n.activityTxTimeNow,
        colors: leaving,
        icon: proposalIcon,
        isSend: true,
        amount: BigInt.from(6),
        hideAmount: false,
        counterparty: short(recipient),
        prefix: null,
      ));
    });

    test('executed: settled, the fee to execute; none known, no amount', () {
      MultisigProposalExecutedEvent executed({BigInt? fee}) => MultisigProposalExecutedEvent(
        id: 'executed',
        executorId: me,
        multisigAddress: msig.accountId,
        recipient: recipient,
        amount: BigInt.from(500),
        proposalId: 4,
        approvers: [me, other],
        result: 'ok',
        timestamp: fiveMinutesAgo,
        blockNumber: 1,
        blockHash: '0xblock',
        fee: fee,
      );

      expect(rowOf(executed(fee: BigInt.from(6))), (
        label: l10n.activityTxProposalExecuted,
        time: l10n.activityTxTimeMinutesAgo(5),
        colors: settledSend,
        icon: proposalIcon,
        isSend: true,
        amount: BigInt.from(6),
        hideAmount: false,
        counterparty: short(recipient),
        prefix: null,
      ));
      expect(rowOf(executed()).hideAmount, isTrue);
    });

    test('cancelling: on its way out, now, the fee to cancel; none known, no amount', () {
      PendingMultisigCancellationEvent cancelling({BigInt? fee}) => PendingMultisigCancellationEvent.create(
        multisigAddress: msig.accountId,
        proposalId: 4,
        proposerId: me,
        recipient: recipient,
        amount: BigInt.from(500),
        fee: fee,
      );

      expect(rowOf(cancelling(fee: BigInt.from(5))), (
        label: l10n.activityTxCancelling,
        time: l10n.activityTxTimeNow,
        colors: leaving,
        icon: proposalIcon,
        isSend: true,
        amount: BigInt.from(5),
        hideAmount: false,
        counterparty: short(recipient),
        prefix: null,
      ));
      expect(rowOf(cancelling()).hideAmount, isTrue);
    });

    test('cancelled: settled, the fee to cancel', () {
      final event = MultisigProposalCancelledEvent(
        id: 'cancelled',
        proposerId: me,
        multisigAddress: msig.accountId,
        recipient: recipient,
        amount: BigInt.from(500),
        proposalId: 4,
        timestamp: fiveMinutesAgo,
        blockNumber: 1,
        blockHash: '0xblock',
        fee: BigInt.from(5),
      );

      expect(rowOf(event), (
        label: l10n.activityTxProposalCancelled,
        time: l10n.activityTxTimeMinutesAgo(5),
        colors: settledSend,
        icon: proposalIcon,
        isSend: true,
        amount: BigInt.from(5),
        hideAmount: false,
        counterparty: short(recipient),
        prefix: null,
      ));
    });

    test('a proposal of a multisig\'s own list: settled, the amount, as of its last change', () {
      expect(rowOf(MultisigProposalEvent(proposal: proposal()), accountId: msig.accountId), (
        label: l10n.activityTxProposal,
        time: l10n.activityTxTimeDaysAgo(2),
        colors: settledSend,
        icon: proposalIcon,
        isSend: true,
        amount: BigInt.from(500),
        hideAmount: false,
        counterparty: short(recipient),
        prefix: null,
      ));
    });
  });

  group('multisig creation', () {
    final multisigIcon = Icons.groups_outlined;

    test('creating: on its way out, now, what it costs, the new multisig after "Multisig"', () {
      final event = PendingMultisigCreationEvent(
        tempId: 'creating',
        creatorId: me,
        multisigAddress: msig.accountId,
        threshold: 2,
        nonce: BigInt.zero,
        signers: [me, other],
        palletFee: BigInt.from(4),
        networkFee: BigInt.from(3),
        timestamp: DateTime.now(),
      );

      expect(rowOf(event), (
        label: l10n.activityTxMultisigCreating,
        time: l10n.activityTxTimeNow,
        colors: leaving,
        icon: multisigIcon,
        isSend: true,
        amount: BigInt.from(7),
        hideAmount: false,
        counterparty: short(msig.accountId),
        prefix: l10n.activityTxMultisigLabel,
      ));
    });

    test('created: settled, what it cost', () {
      final event = MultisigCreatedEvent(
        id: 'multisig',
        creatorId: me,
        multisigAddress: msig.accountId,
        threshold: 2,
        nonce: BigInt.zero,
        signers: [me, other],
        palletFee: BigInt.from(4),
        networkFee: BigInt.from(3),
        timestamp: threeHoursAgo,
        blockNumber: 1,
        blockHash: '0xblock',
      );

      expect(rowOf(event), (
        label: l10n.activityTxMultisigCreated,
        time: l10n.activityTxTimeHoursAgo(3),
        colors: settledSend,
        icon: multisigIcon,
        isSend: true,
        amount: BigInt.from(7),
        hideAmount: false,
        counterparty: short(msig.accountId),
        prefix: l10n.activityTxMultisigLabel,
      ));
    });
  });
}
