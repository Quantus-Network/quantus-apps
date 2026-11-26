import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_row.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

import '../fakes.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final me = makeAccount(1).accountId;
  final other = makeAccount(2).accountId;
  final recipient = makeAccount(3).accountId;
  final msig = MultisigAccount(
    name: 'Team',
    accountId: 'qzmsig${'x' * 40}',
    signers: [me, other],
    threshold: 2,
    nonce: BigInt.zero,
    myMemberAccountId: me,
  );
  final now = DateTime.utc(2026, 11, 19, 12);
  final fiveMinutesAgo = now.subtract(const Duration(minutes: 5, seconds: 30));

  ActivityRow rowOf(TransactionEvent tx, {bool isPrivate = false}) =>
      activityRowOf(tx, accountId: me, l10n: l10n, isPrivate: isPrivate, now: now);

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
    timestamp: now,
    fee: BigInt.one,
  );

  ReversibleTransferEvent reversible({
    required String from,
    required String to,
    ReversibleTransferStatus status = ReversibleTransferStatus.SCHEDULED,
    Duration runsIn = const Duration(days: 1, hours: 2, minutes: 3, seconds: 30),
  }) => ReversibleTransferEvent(
    id: 'reversible',
    from: from,
    to: to,
    amount: BigInt.from(300),
    timestamp: fiveMinutesAgo,
    txId: '0xtxid',
    status: status,
    scheduledAt: now.add(runsIn),
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

  group('a transfer', () {
    test('sent is settled, its recipient named by whole address', () {
      expect(
        rowOf(transfer(from: me, to: other)),
        ActivityRow(
          label: l10n.activityTxSent,
          timeLabel: l10n.activityTxTimeMinutesAgo(5),
          highlight: ActivityHighlight.none,
          icon: ActivityIcon.direction,
          isSend: true,
          amount: BigInt.from(300),
          hidesAmount: false,
          counterparty: ActivityAccount(other, isRecipient: true),
        ),
      );
    });

    test('received is settled, its sender named by whole address', () {
      expect(
        rowOf(transfer(from: other, to: me)),
        ActivityRow(
          label: l10n.activityTxReceived,
          timeLabel: l10n.activityTxTimeMinutesAgo(5),
          highlight: ActivityHighlight.none,
          icon: ActivityIcon.direction,
          isSend: false,
          amount: BigInt.from(300),
          hidesAmount: false,
          counterparty: ActivityAccount(other, isRecipient: false),
        ),
      );
    });

    test('of the encrypted account is sent and received privately', () {
      expect(rowOf(transfer(from: me, to: other), isPrivate: true).label, l10n.activityTxPrivateSent);
      expect(rowOf(transfer(from: other, to: me), isPrivate: true).label, l10n.activityTxPrivateReceived);
    });

    test('says how long ago it was: now under a minute, then minutes, hours and days', () {
      String timeOf(Duration ago) => rowOf(transfer(from: me, to: other, at: now.subtract(ago))).timeLabel;

      expect(timeOf(const Duration(seconds: 59)), l10n.activityTxTimeNow);
      expect(timeOf(const Duration(minutes: 1)), l10n.activityTxTimeMinutesAgo(1));
      expect(timeOf(const Duration(minutes: 59)), l10n.activityTxTimeMinutesAgo(59));
      expect(timeOf(const Duration(hours: 1)), l10n.activityTxTimeHoursAgo(1));
      expect(timeOf(const Duration(hours: 23, minutes: 59)), l10n.activityTxTimeHoursAgo(23));
      expect(timeOf(const Duration(days: 2, hours: 1)), l10n.activityTxTimeDaysAgo(2));
    });
  });

  group('a transfer not yet settled', () {
    test('sending is leaving, now', () {
      final row = rowOf(pending(from: me, to: other));

      expect(
        (row.label, row.timeLabel, row.highlight, row.isSend),
        (l10n.activityTxSending, l10n.activityTxTimeNow, ActivityHighlight.leaving, true),
      );
    });

    test('receiving is arriving, now', () {
      final row = rowOf(pending(from: other, to: me));

      expect(
        (row.label, row.timeLabel, row.highlight, row.isSend),
        (l10n.activityTxReceiving, l10n.activityTxTimeNow, ActivityHighlight.arriving, false),
      );
    });

    test('of the encrypted account is sending and receiving privately', () {
      expect(rowOf(pending(from: me, to: other), isPrivate: true).label, l10n.activityTxPrivatelySending);
      expect(rowOf(pending(from: other, to: me), isPrivate: true).label, l10n.activityTxPrivatelyReceiving);
    });

    test('scheduled to send is pending and leaving, with the time left until it runs', () {
      final row = rowOf(reversible(from: me, to: other));

      expect(
        (row.label, row.timeLabel, row.highlight),
        (l10n.activityTxPending, l10n.activityTxTimeRemaining('01', '02', '03'), ActivityHighlight.leaving),
      );
    });

    test('scheduled to arrive is receiving and arriving, with the time left', () {
      final row = rowOf(reversible(from: other, to: me));

      expect(
        (row.label, row.timeLabel, row.highlight),
        (l10n.activityTxReceiving, l10n.activityTxTimeRemaining('01', '02', '03'), ActivityHighlight.arriving),
      );
      expect(rowOf(reversible(from: other, to: me), isPrivate: true).label, l10n.activityTxPrivatelyReceiving);
    });

    test('scheduled for a time already past has no time left', () {
      final row = rowOf(reversible(from: me, to: other, runsIn: const Duration(minutes: -3)));

      expect(row.timeLabel, l10n.activityTxTimeRemaining('00', '00', '00'));
    });

    test('scheduled and since run is settled', () {
      final row = rowOf(reversible(from: me, to: other, status: ReversibleTransferStatus.EXECUTED));

      expect((row.label, row.highlight), (l10n.activityTxSent, ActivityHighlight.none));
    });
  });

  group('a private send', () {
    test('received names no sender: the chain does not reveal it', () {
      expect(rowOf(wormhole(from: other, to: me), isPrivate: true).counterparty, const ActivityEncryptedSender());
    });

    test('settled with other transfers names the batch, its recipient unknown', () {
      expect(rowOf(wormhole(from: me, to: ''), isPrivate: true).counterparty, const ActivityAggregatedBatch());
    });

    test('to a known recipient names it', () {
      expect(
        rowOf(wormhole(from: me, to: other), isPrivate: true).counterparty,
        ActivityAccount(other, isRecipient: true),
      );
    });
  });

  group('a multisig proposal', () {
    ActivityRow proposalRow(TransactionEvent tx) => rowOf(tx);

    test('being made is leaving, now, the amount proposed, to its recipient', () {
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

      expect(
        proposalRow(event),
        ActivityRow(
          label: l10n.activityTxProposing,
          timeLabel: l10n.activityTxTimeNow,
          highlight: ActivityHighlight.leaving,
          icon: ActivityIcon.proposal,
          isSend: true,
          amount: BigInt.from(500),
          hidesAmount: false,
          counterparty: ActivityAccount(recipient, isRecipient: true),
        ),
      );
    });

    test('made is settled, the amount proposed', () {
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
      );

      final row = proposalRow(event);
      expect(
        (row.label, row.highlight, row.icon, row.isSend, row.amount, row.counterparty),
        (
          l10n.activityTxProposalCreated,
          ActivityHighlight.none,
          ActivityIcon.proposal,
          true,
          BigInt.from(500),
          ActivityAccount(recipient, isRecipient: true),
        ),
      );
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

    test('approved is settled, at what approving cost; with no cost known, no amount', () {
      final row = proposalRow(approved(fee: BigInt.from(7)));

      expect(
        (row.label, row.highlight, row.amount, row.hidesAmount),
        (l10n.activityTxProposalApproved, ActivityHighlight.none, BigInt.from(7), false),
      );
      expect(proposalRow(approved()).hidesAmount, isTrue);
    });

    test('being approved is leaving, now, at what approving costs; with no cost known, no amount', () {
      PendingMultisigApprovalEvent approving({BigInt? fee}) => PendingMultisigApprovalEvent.create(
        multisigAddress: msig.accountId,
        proposalId: 4,
        approverId: me,
        recipient: recipient,
        amount: BigInt.from(500),
        fee: fee,
      );

      final row = proposalRow(approving(fee: BigInt.from(7)));

      expect(
        (row.label, row.timeLabel, row.highlight, row.amount, row.hidesAmount),
        (l10n.activityTxApproving, l10n.activityTxTimeNow, ActivityHighlight.leaving, BigInt.from(7), false),
      );
      expect(proposalRow(approving()).hidesAmount, isTrue);
    });

    test('being executed is leaving, now, at what executing costs; with no cost known, no amount', () {
      PendingMultisigExecutionEvent executing({BigInt? fee}) => PendingMultisigExecutionEvent.create(
        multisigAddress: msig.accountId,
        proposalId: 4,
        executorId: me,
        recipient: recipient,
        amount: BigInt.from(500),
        fee: fee,
      );

      final row = proposalRow(executing(fee: BigInt.from(6)));

      expect(
        (row.label, row.timeLabel, row.highlight, row.amount, row.hidesAmount),
        (l10n.activityTxExecuting, l10n.activityTxTimeNow, ActivityHighlight.leaving, BigInt.from(6), false),
      );
      expect(proposalRow(executing()).hidesAmount, isTrue);
    });

    test('executed is settled, at what executing cost; with no cost known, no amount', () {
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

      final row = proposalRow(executed(fee: BigInt.from(6)));

      expect(
        (row.label, row.highlight, row.amount),
        (l10n.activityTxProposalExecuted, ActivityHighlight.none, BigInt.from(6)),
      );
      expect(proposalRow(executed()).hidesAmount, isTrue);
    });

    test('being cancelled is leaving, now, at what cancelling costs', () {
      final row = proposalRow(
        PendingMultisigCancellationEvent.create(
          multisigAddress: msig.accountId,
          proposalId: 4,
          proposerId: me,
          recipient: recipient,
          amount: BigInt.from(500),
          fee: BigInt.from(5),
        ),
      );

      expect(
        (row.label, row.timeLabel, row.highlight, row.amount),
        (l10n.activityTxCancelling, l10n.activityTxTimeNow, ActivityHighlight.leaving, BigInt.from(5)),
      );
    });

    test('cancelled is settled, at what cancelling cost', () {
      final row = proposalRow(
        MultisigProposalCancelledEvent(
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
        ),
      );

      expect(
        (row.label, row.highlight, row.amount),
        (l10n.activityTxProposalCancelled, ActivityHighlight.none, BigInt.from(5)),
      );
    });

    test('of a multisig\'s own list is settled, the amount, as of its last change', () {
      final changed = now.subtract(const Duration(days: 2, hours: 1));
      final event = MultisigProposalEvent(
        proposal: MultisigProposal(
          entityId: 'proposal-entity',
          id: 4,
          multisigAddress: msig.accountId,
          proposer: me,
          createdAt: changed,
          updatedAt: changed,
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
        ),
      );

      final row = proposalRow(event);
      expect(
        (row.label, row.timeLabel, row.highlight, row.icon, row.amount, row.counterparty),
        (
          l10n.activityTxProposal,
          l10n.activityTxTimeDaysAgo(2),
          ActivityHighlight.none,
          ActivityIcon.proposal,
          BigInt.from(500),
          ActivityAccount(recipient, isRecipient: true),
        ),
      );
    });
  });

  group('a multisig\'s creation', () {
    test('under way is leaving, now, at what it costs, naming the new multisig', () {
      final row = rowOf(
        PendingMultisigCreationEvent(
          tempId: 'creating',
          creatorId: me,
          multisigAddress: msig.accountId,
          threshold: 2,
          nonce: BigInt.zero,
          signers: [me, other],
          palletFee: BigInt.from(4),
          networkFee: BigInt.from(3),
          timestamp: now,
        ),
      );

      expect(
        row,
        ActivityRow(
          label: l10n.activityTxMultisigCreating,
          timeLabel: l10n.activityTxTimeNow,
          highlight: ActivityHighlight.leaving,
          icon: ActivityIcon.multisig,
          isSend: true,
          amount: BigInt.from(7),
          hidesAmount: false,
          counterparty: ActivityMultisig(msig.accountId),
        ),
      );
    });

    test('done is settled, at what it cost', () {
      final row = rowOf(
        MultisigCreatedEvent(
          id: 'multisig',
          creatorId: other,
          multisigAddress: msig.accountId,
          threshold: 2,
          nonce: BigInt.zero,
          signers: [me, other],
          palletFee: BigInt.from(4),
          networkFee: BigInt.from(3),
          timestamp: fiveMinutesAgo,
          blockNumber: 1,
          blockHash: '0xblock',
        ),
      );

      expect(
        (row.label, row.highlight, row.icon, row.isSend, row.amount, row.counterparty),
        (
          l10n.activityTxMultisigCreated,
          ActivityHighlight.none,
          ActivityIcon.multisig,
          true,
          BigInt.from(7),
          ActivityMultisig(msig.accountId),
        ),
      );
    });
  });

  group('what precedes the counterparty', () {
    test(
      'is To for a recipient, From for a sender or a hidden sender, Multisig for a multisig, nothing for a batch',
      () {
        expect(ActivityAccount(other, isRecipient: true).prefix(l10n), l10n.activityTxTo);
        expect(ActivityAccount(other, isRecipient: false).prefix(l10n), l10n.activityTxFrom);
        expect(const ActivityEncryptedSender().prefix(l10n), l10n.activityTxFrom);
        expect(ActivityMultisig(msig.accountId).prefix(l10n), l10n.activityTxMultisigLabel);
        expect(const ActivityAggregatedBatch().prefix(l10n), isEmpty);
      },
    );

    test('a counterparty with no address is named in words', () {
      expect(const ActivityEncryptedSender().name(l10n), l10n.activitySenderEncrypted);
      expect(const ActivityAggregatedBatch().name(l10n), l10n.activityTxAggregatedBatch);
    });
  });

  group('a mining reward', () {
    test('is received from "Mining reward": there is no sender to name', () {
      final row = rowOf(
        MinerRewardEvent(
          id: 'reward',
          miner: me,
          reward: BigInt.from(9),
          timestamp: fiveMinutesAgo,
          blockNumber: 1,
          blockHash: '0xblock',
        ),
      );

      expect(
        (row.label, row.highlight, row.isSend, row.amount),
        (l10n.activityTxReceived, ActivityHighlight.none, false, BigInt.from(9)),
      );
      expect(
        row.counterparty,
        isA<ActivityUnnamedCounterparty>()
            .having((who) => who.prefix(l10n), 'prefix', l10n.activityTxFrom)
            .having((who) => who.name(l10n), 'name', l10n.activitySenderMiningReward),
      );
    });
  });

  group("a multisig's past proposal", () {
    ActivityRow pastRow(MultisigProposalStatus status) => activityRowOf(
      MultisigProposalEvent(
        proposal: MultisigProposal(
          entityId: 'proposal-entity',
          id: 4,
          multisigAddress: msig.accountId,
          proposer: me,
          createdAt: fiveMinutesAgo,
          updatedAt: fiveMinutesAgo,
          pallet: 'Balances',
          call: 'transfer_allow_death',
          recipient: recipient,
          amount: BigInt.from(500),
          expiryBlock: 1000,
          approvals: [me],
          deposit: BigInt.from(2),
          status: status,
          threshold: 2,
          signerCount: 2,
        ),
      ),
      accountId: msig.accountId,
      l10n: l10n,
      now: now,
    );

    test('is named by how it ended', () {
      expect(
        {for (final status in MultisigProposalStatus.values) status: pastRow(status).label},
        {
          MultisigProposalStatus.active: l10n.activityTxProposal,
          MultisigProposalStatus.approved: l10n.activityTxProposal,
          MultisigProposalStatus.executed: l10n.activityTxProposalExecuted,
          MultisigProposalStatus.cancelled: l10n.activityTxProposalCancelled,
          MultisigProposalStatus.removed: l10n.activityTxProposalRemoved,
          MultisigProposalStatus.unknown: l10n.activityTxProposal,
        },
      );
    });

    test('moved its amount only if it was executed; cancelled or removed, it moved nothing', () {
      expect(
        {
          for (final status in MultisigProposalStatus.values)
            status: (pastRow(status).movedNothing, pastRow(status).amount),
        },
        {
          MultisigProposalStatus.active: (false, BigInt.from(500)),
          MultisigProposalStatus.approved: (false, BigInt.from(500)),
          MultisigProposalStatus.executed: (false, BigInt.from(500)),
          MultisigProposalStatus.cancelled: (true, BigInt.from(500)),
          MultisigProposalStatus.removed: (true, BigInt.from(500)),
          MultisigProposalStatus.unknown: (false, BigInt.from(500)),
        },
      );
    });
  });
}
