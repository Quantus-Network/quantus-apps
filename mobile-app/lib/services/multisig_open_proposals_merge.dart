import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/open_proposal_entry.dart';

/// Merges pending and indexed open proposals, newest first.
///
/// Drops indexed rows that likely duplicate a pending row (brief overlap before
/// polling removes the pending entry).
List<OpenProposalEntry> mergeOpenProposals({
  required List<PendingMultisigProposalEvent> pending,
  required List<MultisigProposal> indexed,
}) {
  final entries = <OpenProposalEntry>[
    ...pending.map(PendingOpenProposalEntry.new),
    for (final proposal in indexed)
      if (!pending.any((p) => _matchesPending(proposal, p))) IndexedOpenProposalEntry(proposal),
  ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return entries;
}

bool _matchesPending(MultisigProposal proposal, PendingMultisigProposalEvent pending) {
  return proposal.multisigAddress == pending.multisigAddress &&
      proposal.recipient == pending.recipient &&
      proposal.amount == pending.amount &&
      proposal.proposer == pending.proposerId;
}
