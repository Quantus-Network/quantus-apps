import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/multisig_activity.dart';
import 'package:wallet_core/models/combined_transactions_list.dart';
import 'package:wallet_core/services/transaction_service.dart';

import '../fakes.dart';

void main() {
  final me = makeAccount(1);
  final alsoMe = makeAccount(2);
  final them = makeAccount(3).accountId;
  final recipient = makeAccount(4).accountId;
  final msig = MultisigAccount(
    name: 'Team',
    accountId: 'qzteam${'x' * 40}',
    signers: [me.accountId, alsoMe.accountId, them],
    threshold: 2,
    nonce: BigInt.zero,
    myMemberAccountId: me.accountId,
  );
  final elsewhere = MultisigAccount(
    name: 'Other',
    accountId: 'qzother${'x' * 40}',
    signers: [me.accountId, them],
    threshold: 2,
    nonce: BigInt.zero,
    myMemberAccountId: me.accountId,
  );

  MultisigProposal proposal({
    int id = 1,
    int amount = 500,
    DateTime? updatedAt,
    List<String> approvals = const [],
    MultisigProposalStatus status = MultisigProposalStatus.active,
  }) => MultisigProposal(
    entityId: 'proposal-$id',
    id: id,
    multisigAddress: msig.accountId,
    proposer: me.accountId,
    createdAt: DateTime.utc(2026),
    updatedAt: updatedAt ?? DateTime.utc(2026),
    pallet: '',
    call: '',
    recipient: recipient,
    amount: BigInt.from(amount),
    expiryBlock: 1000,
    approvals: approvals,
    deposit: BigInt.zero,
    status: status,
    threshold: msig.threshold,
    signerCount: msig.signers.length,
  );

  PendingMultisigProposalEvent proposing(MultisigAccount of, {int amount = 300}) => PendingMultisigProposalEvent.create(
    msig: of,
    proposerId: me.accountId,
    recipient: recipient,
    amount: BigInt.from(amount),
    expiryBlock: 1000,
    fee: BigInt.one,
    deposit: BigInt.one,
    palletFee: BigInt.one,
  );

  group('open proposals', () {
    test("the ones being proposed come first, this multisig's only; then the open ones, last changed first", () {
      final mine = proposing(msig);
      final open = openProposalsOf(
        msig,
        proposing: [proposing(elsewhere), mine],
        open: [
          proposal(id: 1, updatedAt: DateTime.utc(2026, 1)),
          proposal(id: 2, updatedAt: DateTime.utc(2026, 3)),
          proposal(id: 3, updatedAt: DateTime.utc(2026, 2)),
        ],
      );

      expect(open.proposing, [mine]);
      expect(open.open.map((p) => p.id), [2, 3, 1]);
    });
  });

  group('what an open proposal waits for', () {
    PendingMultisigApprovalEvent approving(String approverId) => PendingMultisigApprovalEvent.create(
      multisigAddress: msig.accountId,
      proposalId: 1,
      approverId: approverId,
      recipient: recipient,
      amount: BigInt.from(500),
    );
    final executing = PendingMultisigExecutionEvent.create(
      multisigAddress: msig.accountId,
      proposalId: 1,
      executorId: me.accountId,
      recipient: recipient,
      amount: BigInt.from(500),
      fee: BigInt.one,
    );
    final cancelling = PendingMultisigCancellationEvent.create(
      multisigAddress: msig.accountId,
      proposalId: 1,
      proposerId: me.accountId,
      recipient: recipient,
      amount: BigInt.from(500),
      fee: BigInt.one,
    );

    ProposalWait waitOf(
      MultisigProposal of, {
      List<String>? localSignerIds,
      List<PendingMultisigApprovalEvent> approvals = const [],
      List<PendingMultisigExecutionEvent> executions = const [],
      List<PendingMultisigCancellationEvent> cancellations = const [],
    }) => proposalWaitOf(
      of,
      localSignerIds: localSignerIds ?? [me.accountId],
      approvals: approvals,
      executions: executions,
      cancellations: cancellations,
    );

    final both = [me.accountId, alsoMe.accountId];

    test('open, not yet signed by this device', () {
      expect(waitOf(proposal()), ProposalWait.proposed);
    });

    test('open, signed by this device', () {
      expect(waitOf(proposal(approvals: [me.accountId])), ProposalWait.signed);
    });

    test("this device's approval on its way", () {
      expect(waitOf(proposal(), approvals: [approving(me.accountId)]), ProposalWait.approving);
    });

    test('two signers here: approving only once every one yet to sign is on its way', () {
      expect(
        waitOf(
          proposal(approvals: [me.accountId]),
          localSignerIds: both,
          approvals: [approving(alsoMe.accountId)],
        ),
        ProposalWait.approving,
      );
      expect(waitOf(proposal(approvals: [me.accountId]), localSignerIds: both), ProposalWait.proposed);
      expect(waitOf(proposal(), localSignerIds: both, approvals: [approving(me.accountId)]), ProposalWait.proposed);
    });

    test('an execution on its way, named before an approval on its way', () {
      expect(waitOf(proposal(), executions: [executing]), ProposalWait.executing);
      expect(waitOf(proposal(), approvals: [approving(me.accountId)], executions: [executing]), ProposalWait.executing);
    });

    test('a cancellation on its way', () {
      expect(waitOf(proposal(), cancellations: [cancelling]), ProposalWait.cancelling);
    });

    test("another multisig's or another proposal's steps are not this one's", () {
      expect(
        waitOf(
          proposal(),
          approvals: [
            PendingMultisigApprovalEvent.create(
              multisigAddress: elsewhere.accountId,
              proposalId: 1,
              approverId: me.accountId,
              recipient: recipient,
              amount: BigInt.from(500),
            ),
            PendingMultisigApprovalEvent.create(
              multisigAddress: msig.accountId,
              proposalId: 2,
              approverId: me.accountId,
              recipient: recipient,
              amount: BigInt.from(500),
            ),
          ],
        ),
        ProposalWait.proposed,
      );
    });

    test('a closed proposal waits for nothing', () {
      expect(
        waitOf(proposal(approvals: [me.accountId, them], status: MultisigProposalStatus.executed)),
        ProposalWait.closed,
      );
    });
  });

  group("this device's signers of a multisig", () {
    test("the wallet's accounts among its signers", () {
      expect(localSignerIdsOf(msig, [me, alsoMe, makeAccount(9)]), [me.accountId, alsoMe.accountId]);
    });

    test('before any account has loaded, the member it was stored with', () {
      expect(localSignerIdsOf(msig, const []), [me.accountId]);
    });
  });

  group("a multisig's activity", () {
    final container = ProviderContainer();
    tearDownAll(container.dispose);
    final service = container.read(transactionServiceProvider);

    TransferEvent transfer({required String from, required String to, required int day}) => TransferEvent(
      id: 'transfer-$day',
      from: from,
      to: to,
      amount: BigInt.from(day * 100),
      timestamp: DateTime.utc(2026, 3, day),
      fee: BigInt.one,
      blockNumber: day,
      blockHash: '0xblock$day',
    );

    test("past proposals and transfers, newest first, without the multisig's own sends", () {
      final received = transfer(from: me.accountId, to: msig.accountId, day: 3);
      final activity = multisigActivityOf(
        service,
        CombinedTransactionsList.empty.copyWith(
          otherTransfers: [
            received,
            // What an executed proposal sent: the proposal stands for it.
            transfer(from: msig.accountId, to: recipient, day: 4),
            transfer(from: them, to: msig.accountId, day: 1),
          ],
        ),
        [proposal(id: 7, updatedAt: DateTime.utc(2026, 3, 2), status: MultisigProposalStatus.executed)],
        msig,
      );

      expect(activity.map((tx) => tx.id), [received.id, 'proposal-7', 'transfer-1']);
      expect(activity[1], isA<MultisigProposalEvent>().having((tx) => tx.proposalId, 'proposalId', 7));
    });

    test('its own proposals on their way are left out: they are among its open proposals', () {
      final ours = proposing(msig);
      final theirs = proposing(elsewhere, amount: 400);
      final activity = multisigActivityOf(
        service,
        CombinedTransactionsList.empty.copyWith(pendingMultisigProposals: [ours, theirs]),
        const [],
        msig,
      );

      expect(activity, [theirs]);
    });

    test('its approvals on their way are left out: they are among its open proposals', () {
      PendingMultisigApprovalEvent approving(MultisigAccount of) => PendingMultisigApprovalEvent.create(
        multisigAddress: of.accountId,
        proposalId: 1,
        approverId: me.accountId,
        recipient: recipient,
        amount: BigInt.from(500),
      );
      final ours = approving(msig);
      final theirs = approving(elsewhere);
      final activity = multisigActivityOf(
        service,
        CombinedTransactionsList.empty.copyWith(pendingMultisigApprovals: [ours, theirs]),
        const [],
        msig,
      );

      expect(activity, [theirs]);
    });
  });
}
