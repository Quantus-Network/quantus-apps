import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_detail.dart';
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
  final at = DateTime.utc(2026, 9, 6);
  String link(String path) => '${AppConstants.explorerEndpoint}/$path';

  ActivityDetail detailOf(TransactionEvent tx, {bool isPrivate = false}) =>
      activityDetailOf(tx, accountId: me, l10n: l10n, isPrivate: isPrivate);

  TransferEvent transfer({required String from, required String to}) => TransferEvent(
    id: 'tx',
    from: from,
    to: to,
    amount: BigInt.from(300),
    timestamp: at,
    fee: BigInt.one,
    extrinsicHash: '0x9cbe',
    blockNumber: 1,
    blockHash: '0xblock',
  );

  PendingTransactionEvent pending({String? extrinsicHash}) => PendingTransactionEvent(
    tempId: 'pending',
    from: me,
    to: other,
    amount: BigInt.from(300),
    timestamp: at,
    fee: BigInt.one,
    extrinsicHash: extrinsicHash,
  );

  ReversibleTransferEvent reversible({required String from, required ReversibleTransferStatus status}) =>
      ReversibleTransferEvent(
        id: 'reversible',
        from: from,
        to: from == me ? other : me,
        amount: BigInt.from(300),
        timestamp: at,
        txId: '0xtxid',
        status: status,
        scheduledAt: at.add(const Duration(days: 1)),
        blockNumber: 1,
        blockHash: '0xblock',
      );

  WormholeTransferEvent privateSend() => WormholeTransferEvent(
    id: 'wormhole',
    from: me,
    to: other,
    amount: BigInt.from(300),
    timestamp: at,
    fee: BigInt.one,
    extrinsicHash: '0xwormhole',
    blockNumber: 1,
  );

  group('a transfer', () {
    test('sent, completed, its page on the explorer', () {
      expect(
        detailOf(transfer(from: me, to: other)),
        ActivityDetail(
          title: l10n.activityDetailTitleSent,
          status: ActivityStatus.completed,
          isSend: true,
          explorerUrl: link('transactions/0x9cbe'),
        ),
      );
    });

    test('received, completed', () {
      expect(
        detailOf(transfer(from: other, to: me)),
        ActivityDetail(
          title: l10n.activityDetailTitleReceived,
          status: ActivityStatus.completed,
          isSend: false,
          explorerUrl: link('transactions/0x9cbe'),
        ),
      );
    });

    test('of the encrypted account, sent and received privately', () {
      expect(detailOf(transfer(from: me, to: other), isPrivate: true).title, l10n.activityDetailTitlePrivateSent);
      expect(detailOf(transfer(from: other, to: me), isPrivate: true).title, l10n.activityDetailTitlePrivateReceived);
    });

    test('being sent is in process, with no page until it is broadcast', () {
      expect(
        detailOf(pending()),
        ActivityDetail(
          title: l10n.activityDetailTitleSending,
          status: ActivityStatus.inProcess,
          isSend: true,
          explorerUrl: null,
        ),
      );
      expect(detailOf(pending(extrinsicHash: '0xpending')).explorerUrl, link('transactions/0xpending'));
      expect(detailOf(pending(), isPrivate: true).title, l10n.activityDetailTitlePrivatelySending);
    });

    test('scheduled to send is scheduled; to arrive, receiving', () {
      expect(
        detailOf(reversible(from: me, status: ReversibleTransferStatus.SCHEDULED)),
        ActivityDetail(
          title: l10n.activityDetailTitleScheduled,
          status: ActivityStatus.scheduled,
          isSend: true,
          explorerUrl: link('transactions/scheduled-reversible/0xtxid'),
        ),
      );
      final arriving = detailOf(reversible(from: other, status: ReversibleTransferStatus.SCHEDULED));
      expect((arriving.title, arriving.status), (l10n.activityDetailTitleReceiving, ActivityStatus.scheduled));
      expect(
        detailOf(reversible(from: other, status: ReversibleTransferStatus.SCHEDULED), isPrivate: true).title,
        l10n.activityDetailTitlePrivatelyReceiving,
      );
    });

    test('scheduled and since run or cancelled is completed, on its own page', () {
      final ran = detailOf(reversible(from: me, status: ReversibleTransferStatus.EXECUTED));
      final cancelled = detailOf(reversible(from: me, status: ReversibleTransferStatus.CANCELLED));

      expect(
        (ran.title, ran.status, ran.explorerUrl),
        (l10n.activityDetailTitleSent, ActivityStatus.completed, link('transactions/executed-reversible/0xtxid')),
      );
      expect(cancelled.explorerUrl, link('transactions/cancelled-reversible/0xtxid'));
    });

    test('a private send has its page among the private transactions', () {
      expect(detailOf(privateSend()).explorerUrl, link('transactions/wormhole/0xwormhole'));
    });

    test('a mining reward has its block\'s page', () {
      final reward = MinerRewardEvent(
        id: 'reward',
        miner: me,
        reward: BigInt.from(9),
        timestamp: at,
        blockNumber: 1,
        blockHash: '0xrewardblock',
      );

      expect(
        detailOf(reward),
        ActivityDetail(
          title: l10n.activityDetailTitleReceived,
          status: ActivityStatus.completed,
          isSend: false,
          explorerUrl: link('miner-rewards/0xrewardblock'),
        ),
      );
    });
  });

  group('a multisig proposal', () {
    test('being made is in process; its page is the proposal\'s', () {
      final event = PendingMultisigProposalEvent.create(
        msig: msig,
        proposerId: me,
        recipient: recipient,
        amount: BigInt.from(500),
        expiryBlock: 1000,
      ).copyWith(extrinsicHash: '0xproposing');

      expect(
        detailOf(event),
        ActivityDetail(
          title: l10n.activityDetailTitleProposing,
          status: ActivityStatus.inProcess,
          isSend: true,
          explorerUrl: link('multisig-proposal-created/0xproposing'),
        ),
      );
    });

    test('made, approved, executed and cancelled are completed, each on its own page', () {
      final created = MultisigProposalCreatedEvent(
        id: 'created',
        proposerId: other,
        multisigAddress: msig.accountId,
        recipient: recipient,
        amount: BigInt.from(500),
        palletFee: BigInt.one,
        deposit: BigInt.from(2),
        timestamp: at,
        blockNumber: 1,
        blockHash: '0xblock',
        extrinsicHash: '0xcreated',
      );
      final approved = MultisigProposalApprovedEvent(
        id: 'approved',
        approverId: other,
        multisigAddress: msig.accountId,
        recipient: recipient,
        amount: BigInt.from(500),
        proposalId: 4,
        approvalsCount: 2,
        timestamp: at,
        blockNumber: 1,
        blockHash: '0xblock',
        extrinsicHash: '0xapproved',
      );
      final executed = MultisigProposalExecutedEvent(
        id: 'executed',
        executorId: other,
        multisigAddress: msig.accountId,
        recipient: recipient,
        amount: BigInt.from(500),
        proposalId: 4,
        approvers: [me, other],
        result: 'ok',
        timestamp: at,
        blockNumber: 1,
        blockHash: '0xblock',
        extrinsicHash: '0xexecuted',
      );
      final cancelled = MultisigProposalCancelledEvent(
        id: 'cancelled',
        proposerId: other,
        multisigAddress: msig.accountId,
        recipient: recipient,
        amount: BigInt.from(500),
        proposalId: 4,
        timestamp: at,
        blockNumber: 1,
        blockHash: '0xblock',
        extrinsicHash: '0xcancelled',
      );

      expect(
        [
          for (final event in [created, approved, executed, cancelled]) detailOf(event),
        ],
        [
          ActivityDetail(
            title: l10n.activityDetailTitleProposalCreated,
            status: ActivityStatus.completed,
            isSend: true,
            explorerUrl: link('multisig-proposal-created/0xcreated'),
          ),
          ActivityDetail(
            title: l10n.activityDetailTitleProposalApproved,
            status: ActivityStatus.completed,
            isSend: true,
            explorerUrl: link('multisig-signer-approved/0xapproved'),
          ),
          ActivityDetail(
            title: l10n.activityDetailTitleProposalExecuted,
            status: ActivityStatus.completed,
            isSend: true,
            explorerUrl: link('multisig-proposal-executed/0xexecuted'),
          ),
          ActivityDetail(
            title: l10n.activityDetailTitleProposalCancelled,
            status: ActivityStatus.completed,
            isSend: true,
            explorerUrl: link('multisig-proposal-cancelled/0xcancelled'),
          ),
        ],
      );
    });

    test('being executed or cancelled is in process, on the transaction\'s page', () {
      final executing = PendingMultisigExecutionEvent.create(
        multisigAddress: msig.accountId,
        proposalId: 4,
        executorId: me,
        recipient: recipient,
        amount: BigInt.from(500),
      ).copyWith(extrinsicHash: '0xexecuting');
      final cancelling = PendingMultisigCancellationEvent.create(
        multisigAddress: msig.accountId,
        proposalId: 4,
        proposerId: me,
        recipient: recipient,
        amount: BigInt.from(500),
      ).copyWith(extrinsicHash: '0xcancelling');

      expect(
        detailOf(executing),
        ActivityDetail(
          title: l10n.activityDetailTitleExecuting,
          status: ActivityStatus.inProcess,
          isSend: true,
          explorerUrl: link('transactions/0xexecuting'),
        ),
      );
      expect(
        detailOf(cancelling),
        ActivityDetail(
          title: l10n.activityDetailTitleCancelling,
          status: ActivityStatus.inProcess,
          isSend: true,
          explorerUrl: link('transactions/0xcancelling'),
        ),
      );
    });
  });

  group('a multisig\'s creation', () {
    PendingMultisigCreationEvent creating({required String creator}) => PendingMultisigCreationEvent(
      tempId: 'creating',
      creatorId: creator,
      multisigAddress: msig.accountId,
      threshold: 2,
      nonce: BigInt.zero,
      signers: [me, other],
      palletFee: BigInt.from(4),
      networkFee: BigInt.from(3),
      timestamp: at,
      extrinsicHash: '0xcreating',
    );

    test('under way is in process, on the transaction\'s page; a send only for its creator', () {
      expect(
        detailOf(creating(creator: me)),
        ActivityDetail(
          title: l10n.activityDetailTitleMultisigCreating,
          status: ActivityStatus.inProcess,
          isSend: true,
          explorerUrl: link('transactions/0xcreating'),
        ),
      );
      expect(detailOf(creating(creator: other)).isSend, isFalse);
    });

    test('done is completed, on the multisig\'s page', () {
      final created = MultisigCreatedEvent(
        id: 'multisig',
        creatorId: me,
        multisigAddress: msig.accountId,
        threshold: 2,
        nonce: BigInt.zero,
        signers: [me, other],
        palletFee: BigInt.from(4),
        networkFee: BigInt.from(3),
        timestamp: at,
        blockNumber: 1,
        blockHash: '0xblock',
        extrinsicHash: '0xmultisig',
      );

      expect(
        detailOf(created),
        ActivityDetail(
          title: l10n.activityDetailTitleMultisigCreated,
          status: ActivityStatus.completed,
          isSend: true,
          explorerUrl: link('multisig-created/0xmultisig'),
        ),
      );
    });
  });

  test('each status is named', () {
    expect(ActivityStatus.inProcess.label(l10n), l10n.activityDetailStatusInProcess);
    expect(ActivityStatus.scheduled.label(l10n), l10n.activityDetailStatusScheduled);
    expect(ActivityStatus.completed.label(l10n), l10n.activityDetailStatusCompleted);
  });
}
