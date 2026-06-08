import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/open_proposal_entry.dart';
import 'package:resonance_network_wallet/services/multisig_open_proposals_merge.dart';
import 'package:test/test.dart';

void main() {
  const msigAddress = '5Multisig';
  const proposer = '5Proposer';
  const recipient = '5Recipient';

  MultisigProposal indexedProposal({required DateTime createdAt}) {
    final amount = BigInt.from(100);
    return MultisigProposal(
      entityId: 'entity-${createdAt.millisecondsSinceEpoch}',
      id: createdAt.millisecondsSinceEpoch,
      multisigAddress: msigAddress,
      proposer: proposer,
      createdAt: createdAt,
      pallet: 'Balances',
      call: 'transfer_allow_death',
      callRaw: '',
      recipient: recipient,
      amount: amount,
      expiryBlock: 999,
      approvals: const [],
      deposit: BigInt.zero,
      status: MultisigProposalStatus.active,
      threshold: 2,
      signerCount: 3,
    );
  }

  PendingMultisigProposalEvent pendingProposal({required DateTime timestamp}) {
    final amount = BigInt.from(200);
    return PendingMultisigProposalEvent(
      tempId: 'pending-$timestamp',
      multisigAddress: msigAddress,
      proposerId: proposer,
      recipient: recipient,
      amount: amount,
      deposit: BigInt.zero,
      expiryBlock: 999,
      palletFee: BigInt.zero,
      timestamp: timestamp,
    );
  }

  test('sorts pending and indexed proposals newest first', () {
    final older = DateTime(2024, 1, 1);
    final newer = DateTime(2024, 6, 1);

    final merged = mergeOpenProposals(
      pending: [pendingProposal(timestamp: older)],
      indexed: [indexedProposal(createdAt: newer)],
    );

    expect(merged.length, 2);
    expect(merged.first, isA<IndexedOpenProposalEntry>());
    expect(merged.last, isA<PendingOpenProposalEntry>());
  });

  test('deduplicates indexed proposal matching pending overlap', () {
    final timestamp = DateTime(2024, 3, 1);
    final amount = BigInt.from(100);
    final pending = PendingMultisigProposalEvent(
      tempId: 'pending-overlap',
      multisigAddress: msigAddress,
      proposerId: proposer,
      recipient: recipient,
      amount: amount,
      deposit: BigInt.zero,
      expiryBlock: 999,
      palletFee: BigInt.zero,
      timestamp: timestamp,
    );
    final indexed = indexedProposal(createdAt: timestamp);

    final merged = mergeOpenProposals(pending: [pending], indexed: [indexed]);

    expect(merged.length, 1);
    expect(merged.single, isA<PendingOpenProposalEntry>());
  });
}
