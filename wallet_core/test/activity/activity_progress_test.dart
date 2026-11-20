import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_progress.dart';

import '../fakes.dart';

void main() {
  final me = makeAccount(1).accountId;
  final other = makeAccount(2).accountId;
  final msig = MultisigAccount(
    name: 'Team',
    accountId: 'qzteam${'x' * 40}',
    signers: [me, other],
    threshold: 2,
    nonce: BigInt.zero,
    myMemberAccountId: me,
  );
  final at = DateTime.utc(2026, 9, 6);

  PendingTransactionEvent sending({TransactionState state = TransactionState.created, String id = 'sending'}) =>
      PendingTransactionEvent(
        tempId: id,
        from: me,
        to: other,
        amount: BigInt.from(300),
        timestamp: at,
        fee: BigInt.one,
        transactionState: state,
      );

  ReversibleTransferEvent reversible(ReversibleTransferStatus status, {String id = 'reversible'}) =>
      ReversibleTransferEvent(
        id: id,
        from: me,
        to: other,
        amount: BigInt.from(300),
        timestamp: at,
        txId: '0xtxid',
        status: status,
        scheduledAt: at.add(const Duration(days: 1)),
        blockNumber: 1,
        blockHash: '0xblock',
      );

  TransferEvent settled(String id) => TransferEvent(
    id: id,
    from: me,
    to: other,
    amount: BigInt.from(300),
    timestamp: at,
    fee: BigInt.one,
    blockNumber: 1,
    blockHash: '0xblock',
  );

  test('in progress: sends on their way, scheduled transfers, and multisig steps on their way', () {
    final underWay = <TransactionEvent>[
      sending(),
      sending(state: TransactionState.inBlock),
      reversible(ReversibleTransferStatus.SCHEDULED),
      PendingMultisigCreationEvent(
        tempId: 'creating',
        creatorId: me,
        multisigAddress: msig.accountId,
        threshold: 2,
        nonce: BigInt.zero,
        signers: [me, other],
        palletFee: BigInt.one,
        networkFee: BigInt.one,
        timestamp: at,
      ),
      PendingMultisigProposalEvent.create(
        msig: msig,
        proposerId: me,
        recipient: other,
        amount: BigInt.from(500),
        expiryBlock: 1000,
        fee: BigInt.one,
        deposit: BigInt.one,
        palletFee: BigInt.one,
      ),
      PendingMultisigExecutionEvent.create(
        multisigAddress: msig.accountId,
        proposalId: 1,
        executorId: me,
        recipient: other,
        amount: BigInt.from(500),
        fee: BigInt.one,
      ),
      PendingMultisigCancellationEvent.create(
        multisigAddress: msig.accountId,
        proposalId: 1,
        proposerId: me,
        recipient: other,
        amount: BigInt.from(500),
        fee: BigInt.one,
      ),
    ];

    for (final tx in underWay) {
      expect(isActivityInProgress(tx), isTrue, reason: '$tx');
    }
  });

  test('settled: transfers, scheduled transfers that ran or were cancelled, and a send that failed', () {
    final done = <TransactionEvent>[
      settled('settled'),
      reversible(ReversibleTransferStatus.EXECUTED),
      reversible(ReversibleTransferStatus.CANCELLED),
      sending(state: TransactionState.failed),
    ];

    for (final tx in done) {
      expect(isActivityInProgress(tx), isFalse, reason: '$tx');
    }
  });

  test('a list parts into what is in progress and what is settled, each in the order given', () {
    final first = sending(id: 'first');
    final older = settled('older');
    final scheduled = reversible(ReversibleTransferStatus.SCHEDULED, id: 'scheduled');
    final newer = settled('newer');
    final failed = sending(state: TransactionState.failed, id: 'failed');

    final parts = partActivityByProgress([first, newer, scheduled, failed, older]);

    expect(parts.inProgress, [first, scheduled]);
    expect(parts.settled, [newer, failed, older]);
  });
}
