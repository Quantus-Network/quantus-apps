import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/combined_transactions_list.dart';
import 'package:wallet_core/providers/filtered_all_transactions_provider.dart';

void main() {
  final now = DateTime(2026, 11, 20, 14, 2);

  PendingTransactionEvent send(String id, {required String from, required String to}) =>
      PendingTransactionEvent(tempId: id, from: from, to: to, amount: BigInt.one, timestamp: now, fee: BigInt.one);

  final creating = PendingMultisigCreationEvent(
    tempId: 'creating',
    creatorId: 'qzA',
    multisigAddress: 'qzNew',
    threshold: 2,
    nonce: BigInt.zero,
    signers: const ['qzA', 'qzB'],
    palletFee: BigInt.one,
    networkFee: BigInt.one,
    timestamp: now,
  );
  final proposing = PendingMultisigProposalEvent(
    tempId: 'proposing',
    multisigAddress: 'qzTeam',
    proposerId: 'qzA',
    recipient: 'qzC',
    amount: BigInt.one,
    deposit: BigInt.one,
    expiryBlock: 10,
    palletFee: BigInt.one,
  );
  final executing = PendingMultisigExecutionEvent(
    tempId: 'executing',
    multisigAddress: 'qzTeam',
    proposalId: 1,
    executorId: 'qzA',
    recipient: 'qzC',
    amount: BigInt.one,
  );
  final cancelling = PendingMultisigCancellationEvent(
    tempId: 'cancelling',
    multisigAddress: 'qzTeam',
    proposalId: 2,
    proposerId: 'qzA',
    recipient: 'qzC',
    amount: BigInt.one,
  );

  /// Everything the wallet has pending, every account's.
  final pending = CombinedTransactionsList(
    pendingCancellationIds: const {'reversed'},
    pendingTransactions: [
      send('out', from: 'qzA', to: 'qzX'),
      send('in', from: 'qzX', to: 'qzA'),
      send('others', from: 'qzX', to: 'qzY'),
    ],
    pendingMultisigCreations: [creating],
    pendingMultisigProposals: [proposing],
    pendingMultisigExecutions: [executing],
    pendingMultisigCancellations: [cancelling],
    scheduledReversibleTransfers: const [],
    otherTransfers: const [],
  );

  CombinedTransactionsList of(String account, {TransactionFilter filter = TransactionFilter.all}) =>
      combinedTransactionsOf(
        pending,
        accountIds: [account],
        filter: filter,
        scheduledReversibleTransfers: const [],
        otherTransfers: const [],
      );

  test("an account's: what it sends or receives, the multisigs it creates, the proposals it makes, "
      'executes or cancels', () {
    final mine = of('qzA');

    expect(mine.pendingTransactions.map((tx) => tx.id), ['out', 'in']);
    expect(mine.pendingMultisigCreations, [creating]);
    expect(mine.pendingMultisigProposals, [proposing]);
    expect(mine.pendingMultisigExecutions, [executing]);
    expect(mine.pendingMultisigCancellations, [cancelling]);
    expect(mine.pendingCancellationIds, {'reversed'});
  });

  test("another account's holds none of them", () {
    final theirs = of('qzZ');

    expect(theirs.pendingTransactions, isEmpty);
    expect(theirs.pendingMultisigCreations, isEmpty);
    expect(theirs.pendingMultisigProposals, isEmpty);
    expect(theirs.pendingMultisigExecutions, isEmpty);
    expect(theirs.pendingMultisigCancellations, isEmpty);
  });

  test('what was received only holds nothing pending', () {
    final received = of('qzA', filter: TransactionFilter.receive);

    expect(received.pendingTransactions, isEmpty);
    expect(received.pendingMultisigCreations, isEmpty);
    expect(received.pendingMultisigProposals, isEmpty);
    expect(received.pendingMultisigExecutions, isEmpty);
    expect(received.pendingMultisigCancellations, isEmpty);
  });

  test("the history's scheduled and settled transfers are kept as they are", () {
    final scheduled = ReversibleTransferEvent(
      id: 'scheduled',
      from: 'qzA',
      to: 'qzX',
      amount: BigInt.one,
      timestamp: now,
      txId: '0xscheduled',
      status: ReversibleTransferStatus.SCHEDULED,
      scheduledAt: now.add(const Duration(hours: 5)),
      blockNumber: 1,
      blockHash: '0xblock',
    );
    final settled = send('settled', from: 'qzX', to: 'qzA');

    final mine = combinedTransactionsOf(
      pending,
      accountIds: const ['qzA'],
      filter: TransactionFilter.all,
      scheduledReversibleTransfers: [scheduled],
      otherTransfers: [settled],
    );

    expect(mine.scheduledReversibleTransfers, [scheduled]);
    expect(mine.otherTransfers, [settled]);
  });
}
