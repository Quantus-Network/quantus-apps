import 'package:quantus_sdk/quantus_sdk.dart';

/// A row in the multisig open-proposals list: pending or indexed.
sealed class OpenProposalEntry {
  DateTime get timestamp;
}

final class PendingOpenProposalEntry extends OpenProposalEntry {
  final PendingMultisigProposalEvent pending;

  PendingOpenProposalEntry(this.pending);

  @override
  DateTime get timestamp => pending.timestamp;
}

final class IndexedOpenProposalEntry extends OpenProposalEntry {
  final MultisigProposal proposal;

  IndexedOpenProposalEntry(this.proposal);

  @override
  DateTime get timestamp => proposal.createdAt;
}
